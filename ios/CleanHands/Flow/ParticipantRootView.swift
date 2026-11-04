import SwiftUI

/// The participant's screen. Layers, bottom to top (002 choreography §7): camera, state prompts,
/// no-hands guidance, simulation badge, face-guard blank, calm surface, Stop, facilitator strip.
struct ParticipantRootView: View {
    @Bindable var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if showsCamera {
                MetalCameraView(renderer: model.renderer)
                    .ignoresSafeArea()
            }

            stateOverlay
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if model.showNoHandGuidance && model.state.usesCamera {
                Image(systemName: "hand.raised")
                    .font(.system(size: 150, weight: .light))
                    .foregroundStyle(.white.opacity(pulse ? 0.9 : 0.3))
                    .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
                    .onAppear { pulse = true }
                    .onDisappear { pulse = false }
                    .accessibilityHidden(true)
            }

            BadgeLayer(model: model)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, 84)
                .padding(.leading, 28)

            if model.state == .paused(.faceGuard) {
                // Privacy first: on the detection frame, with no transition (FR-020).
                ZStack {
                    Color.black.ignoresSafeArea()
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 120))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .transaction { $0.animation = nil }
            }

            if showsCalmSurface {
                CalmSurface(model: model)
            }

            if isSessionActive {
                StopButton(action: model.participantStop)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(28)
            }

            if model.state != .idle {
                VStack(spacing: 8) {
                    ControlStrip(
                        isPaused: model.isPaused,
                        canGoBack: model.canGoBack,
                        canGoNext: model.canGoNext,
                        onBack: model.back,
                        onNext: model.next,
                        onPause: model.togglePause,
                        onReplay: model.replayNarration,
                        onEnd: model.facilitatorEnd
                    )
                    if model.introNeedsFacilitator {
                        FacilitatorNote(text: "The explanation (N04) did not play. Explain in person that this is a simulation, then tap Next.")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 12)
            }
        }
        .environment(\.locale, Locale(identifier: "sw"))
        .environment(\.qualityLevel, model.quality)
        .onChange(of: reduceMotion, initial: true) { _, value in model.reduceMotion = value }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }

    private var showsCamera: Bool {
        model.state.usesCamera || model.isPaused || model.holdCameraFrame
    }

    private var showsCalmSurface: Bool {
        switch model.state {
        case .debrief, .ended: true
        default: false
        }
    }

    /// Stop is on every screen from session start until the session has ended (FR-007).
    private var isSessionActive: Bool {
        switch model.state {
        case .idle, .ended: false
        default: true
        }
    }

    @ViewBuilder private var stateOverlay: some View {
        switch model.state {
        case .idle:
            IdleView(model: model)
        case .positioning:
            PositioningView()
        case .normalView:
            NormalView()
        case .uvIntro:
            UVIntroView()
        case .uvReveal, .normalView2:
            UVRevealView(mode: model.state == .uvReveal ? .uv : .normal, onShow: model.showView)
        case .paused(.facilitator):
            Image(systemName: "pause.circle")
                .font(.system(size: 100, weight: .light))
                .foregroundStyle(.white.opacity(0.7))
        case .debrief, .ended, .paused:
            EmptyView()
        default:
            if let error = model.cameraError {
                Text(verbatim: error).foregroundStyle(.white).padding()
            } else {
                ProgressView().tint(.white)
            }
        }
    }
}

/// The simulation badge (FR-003, FR-026). It reports when it is fully opaque, because the glow
/// waits for that (002 lamp-transition §6), and it hides at once on face-guard frames.
private struct BadgeLayer: View {
    @Bindable var model: AppModel
    @State private var opacity: Double = 0

    var body: some View {
        SimulationBadge()
            .opacity(opacity)
            .allowsHitTesting(false)
            .onChange(of: model.badgeVisible, initial: true) { _, visible in update(visible) }
    }

    private func update(_ visible: Bool) {
        if visible {
            let restoring: Bool = {
                if case .paused = model.previousState { return true }
                return false
            }()
            if restoring || opacity == 1 {
                // Back from a pause or face guard: restored, not replayed (choreography C8).
                var instant = Transaction()
                instant.disablesAnimations = true
                withTransaction(instant) { opacity = 1 }
                model.setBadgeOpaque(true)
                return
            }
            withAnimation(Motion.quick, completionCriteria: .removed) {
                opacity = 1
            } completion: {
                model.setBadgeOpaque(model.badgeVisible)
            }
        } else {
            model.setBadgeOpaque(false)
            if model.state == .paused(.faceGuard) {
                var instant = Transaction()
                instant.disablesAnimations = true
                withTransaction(instant) { opacity = 0 }
            } else {
                withAnimation(Motion.quick) { opacity = 0 }
            }
        }
    }
}

/// The solid calm screen of the debrief and end. It fades in over the held last camera frame with
/// the lamp's 0.8 s curve, so leaving the camera view never jumps in brightness (FR-024).
private struct CalmSurface: View {
    @Bindable var model: AppModel
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.07, blue: 0.12).ignoresSafeArea()
            if opacity == 1 {
                HStack(spacing: 40) {
                    ForEach(symbols, id: \.self) { symbol in
                        Image(systemName: symbol)
                            .font(.system(size: 90, weight: .regular))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
            }
        }
        .opacity(opacity)
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(Motion.lamp.animation(), completionCriteria: .removed) {
                opacity = 1
            } completion: {
                model.calmSurfaceOpaque()
            }
        }
    }

    private var symbols: [String] {
        model.state == .debrief ? ["lamp.desk.fill", "hands.sparkles.fill"] : ["heart.fill"]
    }
}

/// A short instruction for the facilitator, on the facilitator's side of the screen.
private struct FacilitatorNote: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(.callout.weight(.semibold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.9)))
            .frame(maxWidth: 520)
            .environment(\.locale, .current)
    }
}

/// Facilitator start screen. Registration, consent, and session start arrive with 001 US2.
struct IdleView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "hands.sparkles")
                .font(.system(size: 80, weight: .light))
            Text(verbatim: "Clean Hands")
                .font(.largeTitle.weight(.semibold))
            if let error = model.launchError {
                Text(verbatim: error)
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
            }
            #if DEBUG || QA_TOOLS
            DemoLauncher(model: model)
            #endif
        }
        .foregroundStyle(.white)
        .environment(\.locale, .current)
    }
}
