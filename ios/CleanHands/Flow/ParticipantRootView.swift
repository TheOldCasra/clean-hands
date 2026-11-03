import SwiftUI

/// The participant's screen: live camera underneath, the current state's overlay, and on every
/// screen the Stop control, the facilitator strip, the simulation badge whenever glow is visible,
/// and guidance when no hand has been seen for more than 2 seconds.
struct ParticipantRootView: View {
    @Bindable var model: AppModel
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

            if model.glowVisible {
                SimulationBadge()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(28)
            }

            if model.state != .idle {
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
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 12)
            }

            if isSessionActive {
                StopButton(action: model.participantStop)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(28)
            }
        }
        .environment(\.locale, Locale(identifier: "sw"))
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }

    private var showsCamera: Bool {
        model.state.usesCamera || model.isPaused
    }

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
        case .debrief:
            calmScreen(symbols: ["lamp.desk.fill", "hands.sparkles.fill"])
        case .paused(.faceGuard):
            ZStack {
                Color.black.ignoresSafeArea()
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 120))
                    .foregroundStyle(.white.opacity(0.8))
            }
        case .paused:
            Image(systemName: "pause.circle")
                .font(.system(size: 100, weight: .light))
                .foregroundStyle(.white.opacity(0.7))
        case .ended:
            calmScreen(symbols: ["heart.fill"])
        default:
            if let error = model.cameraError {
                Text(error).foregroundStyle(.white).padding()
            } else {
                ProgressView().tint(.white)
            }
        }
    }

    private func calmScreen(symbols: [String]) -> some View {
        ZStack {
            Color(red: 0.08, green: 0.07, blue: 0.12).ignoresSafeArea()
            HStack(spacing: 40) {
                ForEach(symbols, id: \.self) { symbol in
                    Image(systemName: symbol)
                        .font(.system(size: 90, weight: .regular))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// Facilitator start screen. Registration, consent, and session start arrive with US2.
struct IdleView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "hands.sparkles")
                .font(.system(size: 80, weight: .light))
            Text(verbatim: "Clean Hands")
                .font(.largeTitle.weight(.semibold))
            #if DEBUG || QA_TOOLS
            DemoLauncher(model: model)
            #endif
        }
        .foregroundStyle(.white)
        .environment(\.locale, .current)
    }
}
