import SwiftUI

/// "Place your hands under the screen" (N01): a hand outline and an arrow over the live camera.
/// The no-hand guidance (N02) comes from `ParticipantRootView` on every camera screen.
struct PositioningView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "arrow.down")
                .font(.system(size: 64, weight: .bold))
            Image(systemName: "hand.raised")
                .font(.system(size: 120, weight: .light))
        }
        .foregroundStyle(.white.opacity(0.85))
        .shadow(color: .black.opacity(0.6), radius: 8)
        .accessibilityHidden(true)
    }
}
