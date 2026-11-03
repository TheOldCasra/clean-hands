import Foundation
import Observation
import QuartzCore

/// Owns the camera, tracking, rendering, narration, and session flow, and reacts to each.
@MainActor
@Observable
final class AppModel {
    private(set) var state: SessionState = .idle
    private(set) var handCount = 0
    private(set) var faceVisible = false
    private(set) var glowVisible = false
    private(set) var showNoHandGuidance = false
    private(set) var cameraError: String?
    private(set) var trackingHz: Double = 0
    private(set) var quality: QualityLevel = .high
    private(set) var isDemo = false
    var cameraSetup: CameraSetup = .overheadRear

    @ObservationIgnored let renderer: Renderer
    @ObservationIgnored let narration = NarrationPlayer()
    @ObservationIgnored private let camera = CameraService()
    @ObservationIgnored private let pipeline: TrackingPipeline
    @ObservationIgnored private var machine = SessionStateMachine()
    @ObservationIgnored private(set) var look: LookConfig
    @ObservationIgnored private var cameraConfigured: CameraSetup?
    @ObservationIgnored private var handsSince: Double?
    @ObservationIgnored private var noHandSince: Double?
    @ObservationIgnored private var lastGuidance: Double = -.infinity
    @ObservationIgnored private var lastFrameTime: Double?
    /// Whether this session reached the reveal, so an abort still gets the debrief (FR-021).
    /// Kept here because `entered` runs inside the state machine's mutation and must not read it.
    @ObservationIgnored private var reachedReveal = false

    /// Seed for the demo launcher. Participants get their own seed at registration (US2).
    nonisolated static let demoSeed: UInt64 = 0xC1EA_4A4D_5000_0001

    init() {
        let look = (try? LookConfig.load()) ?? Self.fallbackLook()
        self.look = look
        guard let renderer = Renderer(config: look) else { fatalError("Metal is required") }
        self.renderer = renderer
        self.pipeline = TrackingPipeline(tracker: VisionHandTracker(), setup: .overheadRear)

        machine.onTransition = { [weak self] from, to in self?.entered(to, from: from) }
        renderer.onGlowVisibleChanged = { [weak self] visible in self?.glowVisible = visible }
        renderer.onQualityChanged = { [weak self] level in self?.quality = level }
    }

    private static func fallbackLook() -> LookConfig {
        fatalError("look.json is missing from the app bundle")
    }

    var renderFPS: Double { renderer.renderFPS }

    func updateLook(_ look: LookConfig) {
        self.look = look
        renderer.config = look
    }

    // MARK: - Starting

    /// Starts the reveal flow with the demo seed and no participant record (tasks T047).
    func startDemo() {
        #if DEBUG || QA_TOOLS
        isDemo = true
        renderer.pattern = PatternGenerator.generate(seed: Self.demoSeed, config: look)
        renderer.fade = FadeState(config: look)
        try? machine.transition(to: .deviceReady)
        #endif
    }

    /// Returns false, with `cameraError` set for the facilitator, when the camera cannot start.
    private func startCamera() async -> Bool {
        guard await CameraService.requestAccess() else {
            cameraError = "Camera access is off. Allow it in Settings → Privacy → Camera."
            return false
        }
        do {
            if cameraConfigured != cameraSetup {
                try camera.configure(setup: cameraSetup)
                cameraConfigured = cameraSetup
                pipeline.reset(setup: cameraSetup)
            }
            cameraError = nil
        } catch {
            cameraError = "The camera is not available on this device."
            return false
        }
        let frames = renderer.frames
        let pipeline = pipeline
        camera.setFrameHandler { [weak self] buffer, time in
            frames.store(buffer)
            pipeline.submit(buffer, at: time) { output in
                Task { @MainActor in self?.handle(output) }
            }
        }
        camera.start()
        return true
    }

    private func stopCamera() {
        camera.setFrameHandler(nil)
        camera.stop()
        renderer.frames.clear()
        renderer.resetHands()
        pipeline.reset()
        handCount = 0
        faceVisible = false
    }

    // MARK: - Tracking results

    private func handle(_ output: TrackingPipeline.Output) {
        guard state.usesCamera || state == .paused(.faceGuard) || state == .paused(.facilitator) else { return }
        let now = output.frame.timestamp
        if let last = lastFrameTime, now > last {
            trackingHz = trackingHz == 0 ? 1 / (now - last) : trackingHz * 0.9 + (1 / (now - last)) * 0.1
        }
        lastFrameTime = now
        renderer.update(frame: output.frame)
        renderer.measuredLuma = output.meanLuma ?? renderer.measuredLuma
        handCount = output.frame.hands.count

        if let face = output.faceVisibleChanged {
            faceVisible = face
            if face {
                machine.pause(.faceGuard)
            } else if state == .paused(.faceGuard) {
                renderer.blank = false
                machine.resume()
            }
        }

        // Positioning advances once hands have been seen for half a second.
        if handCount > 0 {
            handsSince = handsSince ?? now
            noHandSince = nil
            showNoHandGuidance = false
        } else {
            handsSince = nil
            noHandSince = noHandSince ?? now
        }
        if state == .positioning, let since = handsSince, now - since >= 0.5 {
            try? machine.transition(to: .normalView)
        }

        // No hands for more than 2 s on any camera screen: guidance (FR-009). The rehearsal
        // pauses with its own clip instead.
        var inRehearsal = false
        if case .rehearsal = state { inRehearsal = true }
        if state.usesCamera, !inRehearsal, let since = noHandSince, now - since > 2 {
            showNoHandGuidance = true
            if now - lastGuidance > 10, !narration.isPlaying || state == .positioning {
                lastGuidance = now
                narration.play("N02")
            }
        }
    }

    // MARK: - Controls

    var canGoBack: Bool {
        [.normalView, .uvIntro, .normalView2].contains(state)
    }

    var canGoNext: Bool {
        switch state {
        case .positioning, .normalView, .uvReveal, .normalView2, .ended: true
        default: false
        }
    }

    var isPaused: Bool {
        if case .paused = state { return true }
        return false
    }

    var viewMode: Renderer.ViewMode { renderer.mode }

    func next() {
        switch state {
        case .positioning: try? machine.transition(to: .normalView)
        case .normalView: try? machine.transition(to: .uvIntro)
        case .uvReveal: try? machine.transition(to: .debrief) // Quick rinse and rehearsal come with US3.
        case .normalView2:
            try? machine.transition(to: .uvReveal)
            try? machine.transition(to: .debrief)
        case .ended: machine.reset()
        default: break
        }
    }

    func back() {
        switch state {
        case .normalView: try? machine.transition(to: .positioning)
        case .uvIntro: try? machine.transition(to: .normalView)
        case .normalView2: try? machine.transition(to: .uvReveal)
        default: break
        }
    }

    func togglePause() {
        if state == .paused(.facilitator) {
            machine.resume()
        } else {
            machine.pause(.facilitator)
        }
    }

    func replayNarration() {
        narration.replay()
    }

    func facilitatorEnd() {
        machine.stop(reason: .facilitatorStopped)
    }

    func participantStop() {
        machine.stop(reason: .participantStopped)
    }

    /// The eye / lamp buttons in the reveal (FR-007).
    func showView(_ mode: Renderer.ViewMode) {
        switch (state, mode) {
        case (.uvReveal, .normal): try? machine.transition(to: .normalView2)
        case (.normalView2, .uv): try? machine.transition(to: .uvReveal)
        default: break
        }
    }

    // MARK: - State entry

    private func entered(_ next: SessionState, from previous: SessionState) {
        state = next
        switch next {
        case .idle:
            isDemo = false
            reachedReveal = false
            renderer.mode = .normal
            renderer.blank = false
        case .deviceReady:
            Task {
                if await startCamera() {
                    try? machine.transition(to: .positioning)
                }
            }
        case .positioning:
            renderer.mode = .normal
            renderer.blank = false
            if previous == .deviceReady || previous == .normalView { narration.play("N01") }
        case .normalView:
            renderer.mode = .normal
            if previous == .positioning { narration.play("N03") }
        case .uvIntro:
            // The spoken explanation always comes before any glow (FR-008, Principle I).
            reachedReveal = true
            renderer.mode = .normal
            narration.play("N04") { [weak self] in
                guard let self, self.state == .uvIntro else { return }
                try? self.machine.transition(to: .uvReveal)
            }
        case .uvReveal:
            renderer.mode = .uv
            if previous == .uvIntro { narration.play(["N05", "N06", "N07"]) }
        case .normalView2:
            renderer.mode = .normal
        case .debrief:
            renderer.mode = .normal
            stopCamera()
            narration.play("N19") { [weak self] in
                guard let self, self.state == .debrief else { return }
                try? self.machine.transition(to: .ended(.completed))
            }
        case .paused(.faceGuard):
            renderer.blank = true
            narration.play("N21")
        case .paused:
            narration.stop()
        case .ended(.aborted):
            stopCamera()
            renderer.blank = true
            // An aborted session still gets the debrief once the reveal has started (FR-021).
            narration.play(reachedReveal ? ["N19", "N20"] : ["N20"])
        case .ended(.completed):
            stopCamera()
        default:
            break
        }
        if case .paused = previous, !next.isEnded, next != .paused(.faceGuard) {
            renderer.blank = false
        }
    }
}
