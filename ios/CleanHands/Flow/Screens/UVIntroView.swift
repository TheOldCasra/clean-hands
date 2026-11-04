import SwiftUI

/// Before the lamp switches on (N04): the lamp icon, while the spoken explanation says this is a
/// picture made by the tablet. The simulation badge comes from `ParticipantRootView`. No glow
/// appears until the explanation has played to its end (002 FR-004b).
struct UVIntroView: View {
    var body: some View {
        Image(systemName: "lamp.desk.fill")
            .font(.system(size: 110, weight: .regular))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.6), radius: 10)
            .accessibilityHidden(true)
    }
}
