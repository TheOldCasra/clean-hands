import SwiftUI

/// Before the lamp switches on (N04): an eye in the middle of the screen, while the spoken
/// explanation says this is a picture made by the tablet. No glow appears until the explanation
/// has played to its end (002 FR-004b).
struct UVIntroView: View {
    var body: some View {
        Image(systemName: "eye.fill")
            .font(.system(size: 110, weight: .regular))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.6), radius: 10)
            .accessibilityHidden(true)
    }
}
