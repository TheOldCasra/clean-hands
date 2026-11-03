import SwiftUI

/// Before the lamp switches on (N04): the lamp icon and the simulation badge, while the spoken
/// explanation says this is a picture made by the tablet. No glow appears until it ends.
struct UVIntroView: View {
    var body: some View {
        VStack(spacing: 28) {
            Image(systemName: "lamp.desk.fill")
                .font(.system(size: 110, weight: .regular))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.6), radius: 10)
            SimulationBadge()
        }
        .accessibilityHidden(true)
    }
}
