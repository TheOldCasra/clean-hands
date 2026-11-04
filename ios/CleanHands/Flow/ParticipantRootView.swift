import SwiftUI

/// The participant's screen. Layers, bottom to top (002 choreography §7): camera, state prompts,
/// simulation badge, face-guard blank, calm surface, exit. The session advances on its own after
/// each voiceover; the exit door ends it from any screen (constitution Principle V).
struct ParticipantRootView: View {
    @Bindable var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if showsCamera {
                MetalCameraView(renderer: model.renderer)
                    .ignoresSafeArea()
            }

            stateOverlay
                .frame(maxWidth: .infinity, maxHeight: .infinity)

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

            if model.introNeedsFacilitator {
                FacilitatorNote(
                    text: "The explanation (N04) did not play. Explain in person that this is a simulation, then continue.",
                    action: model.next
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 28)
            }

            if isSessionActive {
                ExitButton(action: model.participantStop)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(24)
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

    /// The exit is on every screen from session start until the session has ended (FR-007).
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

/// A short instruction for the facilitator, with the one action it asks for.
private struct FacilitatorNote: View {
    let text: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text(verbatim: text)
                .font(.callout.weight(.semibold))
                .multilineTextAlignment(.center)
            Button(action: action) {
                Text(verbatim: "Continue")
                    .font(.callout.weight(.bold))
                    .padding(.horizontal, 20)
            }
            .buttonStyle(PressableStyle(highlight: .black.opacity(0.15)))
            .background(Capsule().fill(.white.opacity(0.25)))
        }
        .foregroundStyle(.white)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.orange.opacity(0.92)))
        .frame(maxWidth: 520)
        .environment(\.locale, .current)
    }
}

/// Ends the session from any screen, with no confirmation (Principle V).
private struct ExitButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "door.left.hand.open")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(Circle().fill(Color(white: 0.08).opacity(0.85)))
                .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(PressableStyle(shape: Circle(), minHitSize: 64))
        .accessibilityLabel(Text(verbatim: "Exit"))
    }
}

/// The start screen: the logo and name above one big green start button; everything else sits
/// behind the settings gear. Registration and consent arrive with 001 US2.
struct IdleView: View {
    @Bindable var model: AppModel
    @State private var showSettings = false

    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                Image(systemName: "hands.sparkles")
                    .font(.system(size: 80, weight: .light))
                Text(verbatim: "Clean Hands")
                    .font(.largeTitle.weight(.semibold))
                #if DEBUG || QA_TOOLS
                DemoStartButton(model: model)
                    .padding(.top, 28)
                #endif
                if let error = model.launchError {
                    Text(verbatim: error)
                        .font(.callout)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 520)
                }
            }

            #if DEBUG || QA_TOOLS
            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .buttonStyle(PressableStyle(shape: Circle(), minHitSize: 56))
            .accessibilityLabel(Text(verbatim: "Settings"))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(24)
            .sheet(isPresented: $showSettings) { TestSettingsSheet(model: model) }
            #endif
        }
        .foregroundStyle(.white)
        .environment(\.locale, .current)
    }
}
