import CoreGraphics
import CoreVideo
import Testing
import simd
@testable import CleanHands

/// Renders a flat skin-coloured frame with the reference hand through the real Metal pipeline and
/// measures the result with the same rules as `tools/measure_glow.py`.
@MainActor
struct RendererTests {
    static let size = (width: 720, height: 1280)
    static let scale: Float = 250
    static let offset = SIMD2<Float>(360, 1000)

    private func joints() -> [SIMD2<Float>] {
        CoverageEstimator.referencePose.map { $0 * (Self.scale / 100) + Self.offset }
    }

    private func skinFrame() throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        let attributes = [kCVPixelBufferMetalCompatibilityKey: true] as CFDictionary
        CVPixelBufferCreate(nil, Self.size.width, Self.size.height, kCVPixelFormatType_32BGRA, attributes, &buffer)
        let pixelBuffer = try #require(buffer)
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        let base = CVPixelBufferGetBaseAddress(pixelBuffer)!.assumingMemoryBound(to: UInt8.self)
        let rowBytes = CVPixelBufferGetBytesPerRow(pixelBuffer)
        // Light brown skin on the hand, the matte dark cloth everywhere else (research R4).
        let hand = joints() + [Anchoring.extendedJoints(joints(), wristExtent: 0.4)[Joint.forearm]]
        for y in 0..<Self.size.height {
            for x in 0..<Self.size.width {
                let o = y * rowBytes + x * 4
                let onHand = CoverageEstimator.isOnHand(SIMD2(Float(x), Float(y)), joints: hand, scale: Self.scale)
                (base[o], base[o + 1], base[o + 2], base[o + 3]) = onHand ? (110, 140, 190, 255) : (22, 24, 26, 255)
            }
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        return pixelBuffer
    }

    private func render(mode: Renderer.ViewMode) throws -> (pixels: [SIMD3<Float>], image: CGImage) {
        let look = try bundledLook()
        let renderer = try #require(Renderer(config: look))
        renderer.pattern = PatternGenerator.generate(seed: 42, config: look)
        renderer.mode = mode
        let points = joints().map { JointPoint(position: $0, confidence: 1) }
        let hand = TrackedHand(id: 0, chirality: .right, handedness: .right, joints: points, surface: .palm,
                               scale: TrackedHand.scale(of: points))
        let frame = HandFrame(timestamp: 0, imageSize: SIMD2(Float(Self.size.width), Float(Self.size.height)), hands: [hand])
        let image = try #require(renderer.renderOffscreen(pixelBuffer: try skinFrame(), frame: frame))

        let width = image.width, height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let context = CGContext(data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let pixels = stride(from: 0, to: bytes.count, by: 4).map {
            SIMD3(Float(bytes[$0]), Float(bytes[$0 + 1]), Float(bytes[$0 + 2])) / 255
        }
        return (pixels, image)
    }

    private func isGlow(_ c: SIMD3<Float>) -> Bool { c.y > c.x * 1.15 && c.y > c.z * 1.05 && c.y > 0.30 }
    private func isBackground(_ c: SIMD3<Float>) -> Bool { c.max() < 0.09 }

    @Test func uvViewMatchesTheReferenceLook() throws {
        let (pixels, _) = try render(mode: .uv)
        let lit = pixels.filter { !isBackground($0) }
        let glow = lit.filter(isGlow)
        let skin = lit.filter { !isGlow($0) && $0.z >= $0.y }

        // Background goes black around the hands.
        #expect(Float(pixels.count - lit.count) / Float(pixels.count) > 0.6)
        // Glow covers roughly the reference share of the lit hand.
        let coverage = Float(glow.count) / Float(lit.count)
        #expect(coverage > 0.10 && coverage < 0.30, "coverage \(coverage)")
        // Skin is dark violet: blue above red above green, value near the reference.
        let meanSkin = skin.reduce(SIMD3<Float>.zero, +) / Float(max(skin.count, 1))
        #expect(meanSkin.z > meanSkin.x && meanSkin.x > meanSkin.y, "skin \(meanSkin)")
        #expect(meanSkin.max() > 0.15 && meanSkin.max() < 0.35, "skin value \(meanSkin.max())")
        // Glow is green, not yellow or cyan.
        let meanGlow = glow.reduce(SIMD3<Float>.zero, +) / Float(max(glow.count, 1))
        #expect(meanGlow.y > meanGlow.x * 1.2 && meanGlow.y > meanGlow.z * 1.1, "glow \(meanGlow)")
    }

    @Test func glowNeverSpillsOffTheHand() throws {
        let (pixels, _) = try render(mode: .uv)
        let look = try bundledLook()
        let extended = Anchoring.extendedJoints(joints(), wristExtent: Float(look.pattern.wristExtent))
        var spill = 0, glowCount = 0
        for (i, c) in pixels.enumerated() where isGlow(c) {
            glowCount += 1
            let p = SIMD2(Float(i % Self.size.width) + 0.5, Float(i / Self.size.width) + 0.5)
            // Allow a few pixels of soft edge from the low-resolution masks.
            if !CoverageEstimator.isOnHand(p, joints: extended, scale: Self.scale * 1.04) { spill += 1 }
        }
        #expect(glowCount > 0)
        #expect(Float(spill) / Float(max(glowCount, 1)) < 0.01, "spill \(spill) of \(glowCount)")
    }

    @Test func normalViewIsTheCameraImage() throws {
        let (pixels, _) = try render(mode: .normal)
        let skin = SIMD3<Float>(190, 140, 110) / 255
        let cloth = SIMD3<Float>(26, 24, 22) / 255
        #expect(pixels.allSatisfy { simd_distance($0, skin) < 0.02 || simd_distance($0, cloth) < 0.02 })
        #expect(!pixels.contains(where: isGlow))
    }
}
