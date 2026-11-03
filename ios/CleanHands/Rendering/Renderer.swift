import CoreGraphics
import CoreVideo
import Metal
import MetalKit
import QuartzCore
import simd

/// Holds the newest camera frame as a Metal texture. Written on the camera queue, read on main.
/// Frames live in GPU memory only and are replaced by the next one (Principle II).
final class CameraFrameStore: @unchecked Sendable {
    private let lock = NSLock()
    private var cache: CVMetalTextureCache?
    private var latest: (texture: CVMetalTexture, size: SIMD2<Float>)?

    init(device: MTLDevice) {
        CVMetalTextureCacheCreate(nil, nil, device, nil, &cache)
    }

    func store(_ pixelBuffer: CVPixelBuffer) {
        guard let texture = makeTexture(pixelBuffer) else { return }
        let size = SIMD2(Float(CVPixelBufferGetWidth(pixelBuffer)), Float(CVPixelBufferGetHeight(pixelBuffer)))
        lock.withLock { latest = (texture, size) }
    }

    func makeTexture(_ pixelBuffer: CVPixelBuffer) -> CVMetalTexture? {
        guard let cache else { return nil }
        var texture: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(nil, cache, pixelBuffer, nil, .bgra8Unorm,
                                                  CVPixelBufferGetWidth(pixelBuffer), CVPixelBufferGetHeight(pixelBuffer), 0, &texture)
        return texture
    }

    func current() -> (texture: CVMetalTexture, size: SIMD2<Float>)? {
        lock.withLock { latest }
    }

    func clear() {
        lock.withLock { latest = nil }
    }
}

/// Draws the camera view, and in UV view the blacklight look with the participant's glow pattern.
@MainActor
final class Renderer: NSObject, MTKViewDelegate {
    enum ViewMode: String, Sendable { case normal, uv }

    /// Matches `MarkInstance` in Shaders.metal.
    private struct MarkInstance {
        var centerAxis: SIMD4<Float>
        var extent: SIMD4<Float>
        var params: SIMD4<Float>
        var seed: SIMD4<UInt32>
    }

    let device: MTLDevice
    let frames: CameraFrameStore
    private let queue: MTLCommandQueue
    private let poolPipeline: MTLRenderPipelineState
    private let markPipeline: MTLRenderPipelineState
    private let finalPipeline: MTLRenderPipelineState
    private let offscreenPipeline: MTLRenderPipelineState
    private let maxInstances = 2 * 400
    private var instanceBuffers: [MTLBuffer]
    private var bufferIndex = 0
    private let inFlight = DispatchSemaphore(value: 3)
    private var poolTexture: MTLTexture?
    private var coverageTexture: MTLTexture?

    var mode: ViewMode = .normal
    var blank = false
    var config: LookConfig { didSet { configChanged() } }
    var pattern: GlowPattern? { didSet { preparePattern() } }
    var fade: FadeState
    var measuredLuma: Float?
    var onGlowVisibleChanged: ((Bool) -> Void)?
    var onQualityChanged: ((QualityLevel) -> Void)?

    private(set) var quality = QualityController()
    private(set) var renderFPS: Double = 0
    private(set) var glowVisible = false

    private var frame = HandFrame.empty
    private var lastHands: [Int: TrackedHand] = [:]
    private var surfaceAlpha: [Int: Float] = [:]
    private var lastSide: [Int: PatternSide] = [:]
    private var preparedMarks: [Handedness: [PatternSide: [(mark: GlowMark, ordinal: Int)]]] = [:]
    private var gain: Float = 1
    private var targetRampPosition: Float = 0.6
    private var lastDraw: CFTimeInterval = 0

    init?(config: LookConfig) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary() else { return nil }
        self.device = device
        self.queue = queue
        self.frames = CameraFrameStore(device: device)
        self.config = config
        self.fade = FadeState(config: config)

        func pipeline(_ vertex: String, _ fragment: String, _ format: MTLPixelFormat, additive: Bool = false) -> MTLRenderPipelineState? {
            let d = MTLRenderPipelineDescriptor()
            d.vertexFunction = library.makeFunction(name: vertex)
            d.fragmentFunction = library.makeFunction(name: fragment)
            d.colorAttachments[0].pixelFormat = format
            if additive {
                let a = d.colorAttachments[0]!
                a.isBlendingEnabled = true
                a.rgbBlendOperation = .add
                a.alphaBlendOperation = .add
                a.sourceRGBBlendFactor = .one
                a.destinationRGBBlendFactor = .one
                a.sourceAlphaBlendFactor = .one
                a.destinationAlphaBlendFactor = .one
            }
            return try? device.makeRenderPipelineState(descriptor: d)
        }
        guard let pool = pipeline("fullscreenVertex", "poolFragment", .rg16Float),
              let marks = pipeline("markVertex", "markFragment", .rg16Float, additive: true),
              let final = pipeline("fullscreenVertex", "finalFragment", .bgra8Unorm),
              let offscreen = pipeline("fullscreenVertex", "finalFragment", .bgra8Unorm) else { return nil }
        poolPipeline = pool
        markPipeline = marks
        finalPipeline = final
        offscreenPipeline = offscreen
        instanceBuffers = (0..<3).compactMap { _ in
            device.makeBuffer(length: 2 * 400 * MemoryLayout<MarkInstance>.stride, options: .storageModeShared)
        }
        super.init()
        configChanged()
    }

    // MARK: - Inputs

    func update(frame: HandFrame) {
        self.frame = frame
        for hand in frame.hands {
            lastHands[hand.id] = hand
        }
    }

    func resetHands() {
        frame = .empty
        lastHands = [:]
        surfaceAlpha = [:]
        lastSide = [:]
        fade.resetPresence()
    }

    private func configChanged() {
        fade.fadeInSeconds = config.fade.fadeInMs / 1000
        fade.fadeOutSeconds = config.fade.fadeOutMs / 1000
        targetRampPosition = Exposure.targetRampPosition(ramp: config.uvView.skinRamp.map(rgb(hex:)),
                                                         targetValue: Float(config.uvView.skinTargetValue))
    }

    private func preparePattern() {
        preparedMarks = [:]
        guard let pattern else { return }
        for hand in Handedness.allCases {
            for side in PatternSide.allCases {
                var ordinals: [MarkKind: Int] = [:]
                preparedMarks[hand, default: [:]][side] = pattern.marks(hand: hand, side: side).map { mark in
                    let ordinal = ordinals[mark.kind, default: 0]
                    ordinals[mark.kind] = ordinal + 1
                    return (mark, ordinal)
                }
            }
        }
    }

    // MARK: - Drawing

    nonisolated func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    nonisolated func draw(in view: MTKView) {
        MainActor.assumeIsolated { drawFrame(in: view) }
    }

    private func drawFrame(in view: MTKView) {
        let now = CACurrentMediaTime()
        let dt = lastDraw == 0 ? 1.0 / 60 : min(now - lastDraw, 0.1)
        lastDraw = now
        renderFPS = renderFPS == 0 ? 1 / dt : renderFPS * 0.95 + (1 / dt) * 0.05
        advanceFades(dt: dt)

        guard let drawable = view.currentDrawable,
              let camera = frames.current(),
              let cameraTexture = CVMetalTextureGetTexture(camera.texture) else { return }
        inFlight.wait()
        guard let commandBuffer = queue.makeCommandBuffer() else {
            inFlight.signal()
            return
        }
        let drawableSize = SIMD2(Float(view.drawableSize.width), Float(view.drawableSize.height))
        let hands = handsToDraw()
        encode(commandBuffer: commandBuffer, target: drawable.texture, pipeline: finalPipeline,
               cameraTexture: cameraTexture, imageSize: camera.size, targetSize: drawableSize, hands: hands)
        commandBuffer.present(drawable)
        let semaphore = inFlight
        commandBuffer.addCompletedHandler { [weak self] buffer in
            semaphore.signal()
            let seconds = buffer.gpuEndTime - buffer.gpuStartTime
            Task { @MainActor in self?.recordGPU(seconds: seconds) }
        }
        commandBuffer.commit()
        updateGlowVisible(hands: hands)
    }

    private func recordGPU(seconds: Double) {
        if let level = quality.record(frameSeconds: seconds, at: CACurrentMediaTime()) {
            onQualityChanged?(level)
        }
    }

    private func advanceFades(dt: Double) {
        fade.updatePresence(present: Set(frame.hands.map(\.id)), dt: dt)
        let step = Float(dt / max(fade.fadeInSeconds, 0.01))
        for (id, hand) in lastHands {
            let target: Float = hand.surface == .edgeOn ? 0 : 1
            let current = surfaceAlpha[id] ?? 0
            surfaceAlpha[id] = current < target ? min(target, current + step) : max(target, current - step)
            if fade.presence(of: id) == 0, !frame.hands.contains(where: { $0.id == id }) {
                lastHands[id] = nil
                surfaceAlpha[id] = nil
                lastSide[id] = nil
            }
        }
        if let measuredLuma {
            let wanted = min(max(targetRampPosition / max(measuredLuma, 0.02), 0.3), 8)
            gain += (wanted - gain) * 0.1
        }
    }

    private func handsToDraw() -> [(hand: TrackedHand, presence: Float, surfaceAlpha: Float)] {
        lastHands.values.sorted { $0.id < $1.id }.prefix(2).map { hand in
            (hand, fade.presence(of: hand.id), surfaceAlpha[hand.id] ?? 0)
        }
    }

    private func updateGlowVisible(hands: [(hand: TrackedHand, presence: Float, surfaceAlpha: Float)]) {
        let visible = mode == .uv && !blank && pattern != nil && hands.contains { $0.presence * $0.surfaceAlpha > 0.01 }
        if visible != glowVisible {
            glowVisible = visible
            onGlowVisibleChanged?(visible)
        }
    }

    private func ensureTextures(imageSize: SIMD2<Float>) {
        let poolSize = (Int(imageSize.x) / 4, Int(imageSize.y) / 4)
        let coverageSize = (Int(imageSize.x) / 2, Int(imageSize.y) / 2)
        func make(_ size: (Int, Int)) -> MTLTexture? {
            let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rg16Float, width: max(size.0, 1), height: max(size.1, 1), mipmapped: false)
            d.usage = [.renderTarget, .shaderRead]
            d.storageMode = .private
            return device.makeTexture(descriptor: d)
        }
        if poolTexture?.width != poolSize.0 || poolTexture?.height != poolSize.1 { poolTexture = make(poolSize) }
        if coverageTexture?.width != coverageSize.0 || coverageTexture?.height != coverageSize.1 { coverageTexture = make(coverageSize) }
    }

    private func encode(commandBuffer: MTLCommandBuffer, target: MTLTexture, pipeline: MTLRenderPipelineState,
                        cameraTexture: MTLTexture, imageSize: SIMD2<Float>, targetSize: SIMD2<Float>,
                        hands: [(hand: TrackedHand, presence: Float, surfaceAlpha: Float)]) {
        ensureTextures(imageSize: imageSize)
        guard let poolTexture, let coverageTexture else { return }
        let uvMode = mode == .uv && !blank
        let wristExtent = Float(config.pattern.wristExtent)

        if uvMode {
            // 1. Hand light pool.
            let pool = LightPool(hands: hands.map { ($0.hand, $0.presence) }, wristExtent: wristExtent)
            var poolUniforms = pool.uniforms(imageSize: imageSize, config: config)
            let pass = MTLRenderPassDescriptor()
            pass.colorAttachments[0].texture = poolTexture
            pass.colorAttachments[0].loadAction = .clear
            pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
            pass.colorAttachments[0].storeAction = .store
            if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) {
                encoder.setRenderPipelineState(poolPipeline)
                encoder.setFragmentBytes(&poolUniforms, length: MemoryLayout<LightPool.Uniforms>.stride, index: 0)
                var capsules = pool.capsules.isEmpty ? [LightPool.Capsule(ab: .zero, params: .zero)] : pool.capsules
                var palms = pool.palms.isEmpty ? [LightPool.PalmOutline(p01: .zero, p23: .zero, p45: .zero, params: .zero)] : pool.palms
                encoder.setFragmentBytes(&capsules, length: MemoryLayout<LightPool.Capsule>.stride * capsules.count, index: 1)
                encoder.setFragmentBytes(&palms, length: MemoryLayout<LightPool.PalmOutline>.stride * palms.count, index: 2)
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                encoder.endEncoding()
            }

            // 2. Coverage.
            let instances = markInstances(hands: hands, wristExtent: wristExtent)
            let buffer = instanceBuffers[bufferIndex]
            bufferIndex = (bufferIndex + 1) % instanceBuffers.count
            let count = min(instances.count, maxInstances)
            instances.withUnsafeBytes { bytes in
                buffer.contents().copyMemory(from: bytes.baseAddress!, byteCount: count * MemoryLayout<MarkInstance>.stride)
            }
            let coveragePass = MTLRenderPassDescriptor()
            coveragePass.colorAttachments[0].texture = coverageTexture
            coveragePass.colorAttachments[0].loadAction = .clear
            coveragePass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
            coveragePass.colorAttachments[0].storeAction = .store
            if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: coveragePass) {
                if count > 0 {
                    encoder.setRenderPipelineState(markPipeline)
                    encoder.setVertexBuffer(buffer, offset: 0, index: 0)
                    var size = SIMD4<Float>(imageSize.x, imageSize.y, 0, 0)
                    encoder.setVertexBytes(&size, length: MemoryLayout<SIMD4<Float>>.stride, index: 1)
                    encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: count)
                }
                encoder.endEncoding()
            }
        }

        // 3. Final composite.
        var uniforms = finalUniforms(imageSize: imageSize, targetSize: targetSize, uvMode: uvMode, hands: hands)
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = .dontCare
        pass.colorAttachments[0].storeAction = .store
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return }
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<SIMD4<Float>>.stride * uniforms.count, index: 0)
        encoder.setFragmentTexture(cameraTexture, index: 0)
        encoder.setFragmentTexture(poolTexture, index: 1)
        encoder.setFragmentTexture(coverageTexture, index: 2)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
    }

    private func markInstances(hands: [(hand: TrackedHand, presence: Float, surfaceAlpha: Float)], wristExtent: Float) -> [MarkInstance] {
        var instances: [MarkInstance] = []
        let level = quality.level.config(in: config)
        let counts = config.pattern.counts
        let limits: [MarkKind: Int] = [
            .cap: 5,
            .streak: Int((Double(counts.streak) * level.countScale).rounded()),
            .fleck: Int((Double(counts.fleck) * level.countScale).rounded()),
            .patch: Int((Double(counts.patch) * level.countScale).rounded()),
        ]
        let kindIndex: [MarkKind: Float] = [.cap: 0, .streak: 1, .fleck: 2, .patch: 3]
        let grainScale = Float(config.glow.grain.scale)
        let grainStrength = Float(config.glow.grain.strength)

        for entry in hands {
            let hand = entry.hand
            let alpha = entry.presence * entry.surfaceAlpha
            guard alpha > 0.001 else { continue }
            let side: PatternSide
            switch hand.surface {
            case .palm: side = .palm
            case .back: side = .back
            case .edgeOn: guard let previous = lastSide[hand.id] else { continue }
                side = previous
            }
            lastSide[hand.id] = side
            let joints = Anchoring.extendedJoints(hand.joints.map(\.position), wristExtent: wristExtent)
            for (mark, ordinal) in preparedMarks[hand.handedness]?[side] ?? [] where ordinal < limits[mark.kind, default: 0] {
                let p = Anchoring.placement(of: mark, joints: joints, scale: hand.scale)
                let intensity = mark.intensity * alpha * fade.multiplier(hand: hand.handedness, side: side, region: mark.region)
                guard intensity > 0.001 else { continue }
                instances.append(MarkInstance(
                    centerAxis: SIMD4(p.center.x, p.center.y, p.axis.x, p.axis.y),
                    extent: SIMD4(p.halfLength, p.halfWidth, hand.scale, kindIndex[mark.kind]!),
                    params: SIMD4(intensity, mark.hue, grainScale, grainStrength),
                    seed: SIMD4(mark.grainSeed, 0, 0, 0)
                ))
            }
        }
        return instances
    }

    private func finalUniforms(imageSize: SIMD2<Float>, targetSize: SIMD2<Float>, uvMode: Bool,
                               hands: [(hand: TrackedHand, presence: Float, surfaceAlpha: Float)]) -> [SIMD4<Float>] {
        // Aspect fill: crop the camera image to the screen's shape.
        let fill = max(targetSize.x / imageSize.x, targetSize.y / imageSize.y)
        let visible = targetSize / (imageSize * fill)
        let transform = SIMD4(visible.x, visible.y, (1 - visible.x) / 2, (1 - visible.y) / 2)

        let look = config
        let level = quality.level.config(in: look)
        let meanScale = hands.isEmpty ? 100 : hands.map(\.hand.scale).reduce(0, +) / Float(hands.count)
        var u: [SIMD4<Float>] = []
        u.append(transform)
        u.append(SIMD4(uvMode ? 1 : 0, gain, Float(look.uvView.skinLocalContrast), Float(look.glow.skinDetailStrength)))
        u.append(SIMD4(Float(look.glow.bloom.radius) * meanScale, Float(look.glow.bloom.intensity * level.bloomScale),
                       Float(look.glow.hueJitter), blank ? 1 : 0))
        u.append(SIMD4(1 / imageSize.x, 1 / imageSize.y, 0, 0))
        let ramp = look.uvView.skinRamp.map(rgb(hex:))
        for i in 0..<4 { u.append(SIMD4(ramp[min(i, ramp.count - 1)], 1)) }
        let palette = [look.glow.palette.low, look.glow.palette.mid, look.glow.palette.high, look.glow.palette.peak].map(rgb(hex:))
        for color in palette { u.append(SIMD4(color, 1)) }
        u.append(SIMD4(rgb(hex: look.uvView.nailTint.color), Float(look.uvView.nailTint.strength)))
        u.append(SIMD4(rgb(hex: look.uvView.background), 1))
        var tips: [SIMD4<Float>] = []
        for entry in hands {
            for tip in [Joint.thumbTip, .indexTip, .middleTip, .ringTip, .littleTip] {
                let p = entry.hand.point(tip)
                tips.append(SIMD4(p.x, p.y, 0.08 * entry.hand.scale, entry.presence * entry.surfaceAlpha))
            }
        }
        for i in 0..<10 { u.append(i < tips.count ? tips[i] : .zero) }
        u.append(SIMD4(Float(min(tips.count, 10)), 0, 0, 0))
        return u
    }

    // MARK: - Offscreen (replay harness)

    /// Renders one frame as the app would show it in UV view, for the debug replay overlays.
    func renderOffscreen(pixelBuffer: CVPixelBuffer, frame: HandFrame) -> CGImage? {
        guard let cvTexture = frames.makeTexture(pixelBuffer),
              let cameraTexture = CVMetalTextureGetTexture(cvTexture),
              let commandBuffer = queue.makeCommandBuffer() else { return nil }
        let size = SIMD2(Float(CVPixelBufferGetWidth(pixelBuffer)), Float(CVPixelBufferGetHeight(pixelBuffer)))
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: Int(size.x), height: Int(size.y), mipmapped: false)
        d.usage = [.renderTarget, .shaderRead]
        d.storageMode = .shared
        guard let target = device.makeTexture(descriptor: d) else { return nil }
        measuredLuma = Exposure.meanLuma(of: pixelBuffer, hands: frame.hands)
        if let measuredLuma { gain = min(max(targetRampPosition / max(measuredLuma, 0.02), 0.3), 8) }
        let hands = frame.hands.map { ($0, Float(1), Float($0.surface == .edgeOn ? 0 : 1)) }
        for hand in frame.hands where hand.surface != .edgeOn {
            lastSide[hand.id] = hand.surface == .palm ? .palm : .back
        }
        encode(commandBuffer: commandBuffer, target: target, pipeline: offscreenPipeline,
               cameraTexture: cameraTexture, imageSize: size, targetSize: size, hands: hands)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        let width = Int(size.x), height = Int(size.y)
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        target.getBytes(&bytes, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        let info = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                       space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: info, provider: provider, decode: nil,
                       shouldInterpolate: false, intent: .defaultIntent)
    }
}
