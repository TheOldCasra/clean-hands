import SwiftUI

/// The facilitator's discreet strip on the screen edge furthest from the participant (FR-016).
/// It never covers the hands view.
struct ControlStrip: View {
    var isPaused: Bool
    var canGoBack: Bool
    var canGoNext: Bool
    let onBack: () -> Void
    let onNext: () -> Void
    let onPause: () -> Void
    let onReplay: () -> Void
    let onEnd: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            stripButton("chevron.backward", "Back", enabled: canGoBack, action: onBack)
            stripButton(isPaused ? "play.fill" : "pause.fill", isPaused ? "Resume" : "Pause", action: onPause)
            stripButton("arrow.counterclockwise", "Replay", action: onReplay)
            stripButton("xmark", "End", action: onEnd)
            stripButton("chevron.forward", "Next", enabled: canGoNext, action: onNext)
        }
        .padding(6)
        .background(Capsule().fill(.black.opacity(0.35)))
        .opacity(0.7)
    }

    private func stripButton(_ symbol: String, _ label: LocalizedStringKey, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 44, height: 36)
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .accessibilityLabel(Text(label))
    }
}
