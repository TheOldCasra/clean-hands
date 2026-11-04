import Foundation
import Observation
import QuartzCore

/// Owns the camera, tracking, rendering, narration, and session flow, and reacts to each.
///
/// `entered(_:from:)` runs inside the state machine's mutation, so it never calls the machine
/// synchronously; follow-up transitions come from callbacks, timers, or the next tick.
@MainActor
@Observable
final class AppModel {
    private(set) var state: SessionState = .idle
    private(set) var previousState: SessionState = .idle
    private(set) var handCount = 0
    private(set) var faceVisible = false
    private(set) var glowVisible = false
    private(set) var showNoHandGuidance = false
    private(set) var cameraError: String?
    /// Why a session could not start (e.g. missing narration clips), for the facilitator.
    private(set) var launchError: String?
    private(set) var trackingHz: Double = 0
    private(set) var quality: QualityLevel = .high
    private(set) var isDemo = false
    private(set) var badgeRequired = false
    /// Keeps the camera view mounted, showing its last frame, under a calm surface fading in.
    private(set) var holdCameraFrame = false
    /// Whether the badge stays under that calm surface (it was showing when the camera left).
    private(set) var badgeUnderCalm = false
    /// Whether the badge was showing when a pause began, so it stays (or returns) with it.
    private(set) var badgeThroughPause = false
    /// The spoken explanation failed: the facilitator explains in person, then taps Next (FR-004b).
    private(set) var introNeedsFacilitator = false
    private(set) var visiblePrompts: [PromptSchedule.Prompt] = []
    private(set) var turnHandHints = 0
    private(set) var positioningNudges = 0
    private(set) var studySettings: StudySettings?
    var cameraSetup: CameraSetup = .overheadRear
    var reduceMotion = false {
        didSet { renderer.reduceMotion = reduceMotion }
    }

    @ObservationIgnored let renderer: Renderer
    @ObservationIgnored let narration = NarrationPlayer()
    @ObservationIgnored private let camera = CameraService()
    @ObservationIgnored private let pipeline: TrackingPipeline
    @ObservationIgnored private var machine = SessionStateMachine()
    @ObservationIgnored private var schedule = PromptSchedule()
    @ObservationIgnored private(set) var look: LookConfig
    @ObservationIgnored private var cameraConfigured: CameraSetup?
    @ObservationIgnored private var handsSince: Double?
    @ObservationIgnored private var noHandSince: Double?
    @ObservationIgnored private var lastGuidance: Double = -.infinity
    @ObservationIgnored private var lastFrameTime: Double?
    @ObservationIgnored private var lastTick: CFTimeInterval?
    /// Bumped on each uvIntro and uvReveal visit, so a timer from an earlier visit never fires.
    @ObservationIgnored private var visit = 0
    @ObservationIgnored private var revealNarrationPending = false
    /// Whether this session reached the reveal, so an abort still gets the debrief (FR-021).
    @ObservationIgnored private var reachedReveal = false

    /// After the reveal narration (N05–N07) ends, the participant explores the lamp this long
    /// (unpaused) before the session moves on by itself.
    static let revealExplorationSeconds: Double = 45
    /// How long the end screen stays before returning to the start screen.
    static let endScreenSeconds: Double = 4

    /// Unpaused time at which the reveal narration finished; the exploration window starts here.
    @ObservationIgnored private var revealNarrationDoneAt: Double?

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
        renderer.onBadgeRequiredChanged = { [weak self] required in self?.badgeRequired = required }
        renderer.onLampSettled = { [weak self] mode in
            if mode == .uv { self?.startRevealNarration() }
        }
        renderer.onSpreadEnded = { [weak self] in
            self?.schedule.markSpreadEnded()
            self?.syncSchedule()
        }
        narration.onClipPlayed = { [weak self] clip in
            self?.schedule.clipStarted(clip)
            self?.syncSchedule()
        }
        Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                self?.tick()
            }
        }
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
        // A session never starts without every narration clip, above all N04 (FR-004b).
        let missing = NarrationPlayer.missingClips()
        guard missing.isEmpty else {
            launchError = "Missing narration clips: \(missing.joined(separator: ", ")). A session cannot start without them."
            return
        }
        launchError = nil
        isDemo = true
        studySettings = StudySettings.current()
        renderer.pattern = PatternGenerator.generate(seed: Self.demoSeed, config: look)
        renderer.fade = FadeState(config: look)
        renderer.resetLamp()
        schedule.reset()
        syncSchedule()
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

    /// Stops capture. With no new frames the camera view keeps showing its last one, which is
    /// what a calm surface fades in over (002 FR-024).
    private func stopCamera() {
        camera.setFrameHandler(nil)
        camera.stop()
        renderer.frames.clear()
        renderer.resetHands()
        pipeline.reset()
        handCount = 0
        faceVisible = false
    }

    // MARK: - Ticks and schedule

    private func tick() {
        let now = CACurrentMediaTime()
        let dt = lastTick.map { now - $0 } ?? 0
        lastTick = now
        schedule.advance(by: dt, paused: isPaused || state == .idle)
        syncSchedule()
        tryStartLamp()
        // The session continues by itself once the participant has explored the lamp.
        if state == .uvReveal || state == .normalView2, let done = revealNarrationDoneAt,
           schedule.now - done >= Self.revealExplorationSeconds {
            revealNarrationDoneAt = nil
            next()
        }
    }

    private func syncSchedule() {
        let prompts = state == .uvReveal || state == .normalView2 ? schedule.visiblePrompts : []
        if prompts != visiblePrompts { visiblePrompts = prompts }
        if schedule.turnHandHints != turnHandHints { turnHandHints = schedule.turnHandHints }
        if schedule.positioningNudges != positioningNudges { positioningNudges = schedule.positioningNudges }
        let needsFacilitator = state == .uvIntro && schedule.needsFacilitator
        if needsFacilitator != introNeedsFacilitator { introNeedsFacilitator = needsFacilitator }
    }

    /// Leaves uvIntro once the explanation has played and the dwell is over, or once the
    /// facilitator continues after a failed explanation (FR-004b). Never from `entered`.
    private func tryStartLamp() {
        guard state == .uvIntro, schedule.lampMayStart else { return }
        try? machine.transition(to: .uvReveal)
    }

    /// Starts N05–N07 once the lamp has settled (or 1.0 s after the switch), never sooner than the
    /// click's deferral allows (002 lamp-transition §7).
    private func startRevealNarration() {
        guard revealNarrationPending, state == .uvReveal else { return }
        revealNarrationPending = false
        narration.play(["N05", "N06", "N07"]) { [weak self] _ in
            guard let self, self.state == .uvReveal || self.state == .normalView2 else { return }
            self.revealNarrationDoneAt = self.schedule.now
        }
    }

    /// Returns to the start screen a few seconds after the end screen's narration.
    private func returnToStart(after seconds: Double) {
        let thisVisit = visit
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            guard let self, self.visit == thisVisit, self.state.isEnded else { return }
            self.machine.reset()
        }
    }

    /// Called by the calm surface once it is fully opaque: the held frame and badge can go.
    func calmSurfaceOpaque() {
        guard holdCameraFrame else { return }
        holdCameraFrame = false
        badgeUnderCalm = false
        renderer.resetLamp()
        renderer.blank = false
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
        case .uvIntro: introNeedsFacilitator
        default: false
        }
    }

    var isPaused: Bool {
        if case .paused = state { return true }
        return false
    }

    var viewMode: Renderer.ViewMode { renderer.mode }

    /// Whether the simulation badge is on screen (FR-003, choreography §5–§7).
    var badgeVisible: Bool {
        switch state {
        case .paused(.faceGuard): false
        case .uvIntro, .uvReveal, .normalView2: true
        case .paused: badgeThroughPause || badgeRequired
        case .debrief, .ended: holdCameraFrame && badgeUnderCalm
        default: badgeRequired
        }
    }

    /// The badge view reports when it is fully opaque; glow waits for it (lamp-transition §6).
    func setBadgeOpaque(_ opaque: Bool) {
        renderer.badgeOpaque = opaque
    }

    func next() {
        switch state {
        case .positioning: try? machine.transition(to: .normalView)
        case .normalView: try? machine.transition(to: .uvIntro)
        case .uvIntro:
            schedule.facilitatorNext()
            syncSchedule()
            tryStartLamp()
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
        let badgeWasVisible = badgeVisible
        previousState = previous
        state = next
        if case .paused = next {
            badgeThroughPause = badgeWasVisible
            renderer.frozen = true
        } else {
            renderer.frozen = false
        }
        let resumed: Bool = {
            if case .paused = previous { return true }
            return false
        }()

        switch next {
        case .idle:
            isDemo = false
            reachedReveal = false
            revealNarrationDoneAt = nil
            holdCameraFrame = false
            badgeUnderCalm = false
            renderer.blank = false
            renderer.resetLamp()
            schedule.reset()
        case .deviceReady:
            Task {
                if await startCamera() {
                    try? machine.transition(to: .positioning)
                }
            }
        case .positioning:
            renderer.setView(.normal, animated: false)
            if previous == .deviceReady || previous == .normalView { narration.play("N01") }
        case .normalView:
            renderer.setView(.normal, animated: false)
            if previous == .positioning {
                visit += 1
                let thisVisit = visit
                // The session continues by itself when the voiceover ends.
                narration.play("N03") { [weak self] _ in
                    guard let self, self.visit == thisVisit, self.state == .normalView else { return }
                    try? self.machine.transition(to: .uvIntro)
                }
            }
        case .uvIntro:
            // The spoken explanation always comes before any glow (FR-004b, Principle I).
            reachedReveal = true
            renderer.setView(.normal, animated: false)
            guard !resumed else { break }
            visit += 1
            let thisVisit = visit
            schedule.enterIntro()
            narration.play("N04") { [weak self] finished in
                guard let self, self.visit == thisVisit, self.state == .uvIntro else { return }
                self.schedule.explanationEnded(normally: finished)
                self.syncSchedule()
                self.tryStartLamp()
            }
        case .uvReveal:
            guard !resumed else {
                schedule.resumed()
                // A pause stopped the narration chain; the exploration window starts now.
                if !revealNarrationPending, revealNarrationDoneAt == nil { revealNarrationDoneAt = schedule.now }
                break
            }
            let switchedOn = renderer.setView(.uv, animated: true)
            if switchedOn {
                // No clip may start over the lamp switch (FR-016); the click itself comes with US4.
                narration.deferStarts(until: CACurrentMediaTime() + Motion.lamp.seconds)
            }
            schedule.lampSwitched()
            if previous == .uvIntro {
                visit += 1
                let thisVisit = visit
                revealNarrationPending = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    guard let self, self.visit == thisVisit else { return }
                    self.startRevealNarration()
                }
            }
        case .normalView2:
            guard !resumed else { break }
            renderer.setView(.normal, animated: true)
        case .debrief:
            holdCameraFrame = true
            badgeUnderCalm = badgeWasVisible
            stopCamera()
            narration.play("N19") { [weak self] _ in
                guard let self, self.state == .debrief else { return }
                try? self.machine.transition(to: .ended(.completed))
            }
        case .paused(.faceGuard):
            renderer.blank = true
            narration.play("N21")
        case .paused:
            narration.stop()
        case .ended(.aborted):
            holdCameraFrame = true
            badgeUnderCalm = badgeWasVisible
            stopCamera()
            // Only a face-guard abort starts from black; otherwise the last frame is held.
            if previous == .paused(.faceGuard) { renderer.blank = true }
            // An aborted session still gets the debrief once the reveal has started (FR-021).
            visit += 1
            narration.play(reachedReveal ? ["N19", "N20"] : ["N20"]) { [weak self] _ in
                self?.returnToStart(after: Self.endScreenSeconds)
            }
        case .ended(.completed):
            stopCamera()
            visit += 1
            returnToStart(after: Self.endScreenSeconds)
        default:
            break
        }
        if case .paused = previous, !next.isEnded, next != .paused(.faceGuard) {
            renderer.blank = false
        }
        syncSchedule()
    }
}
