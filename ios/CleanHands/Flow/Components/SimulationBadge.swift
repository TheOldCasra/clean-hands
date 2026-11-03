import SwiftUI

/// Marks the glow as a simulation (FR-008, Principle I): a lamp icon with the Swahili label.
/// `ParticipantRootView` shows it whenever the renderer reports glow on screen.
struct SimulationBadge: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "lamp.desk.fill")
                .font(.system(size: 26, weight: .semibold))
            Text("Simulation")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Capsule().fill(.black.opacity(0.6)))
        .overlay(Capsule().stroke(.white.opacity(0.5), lineWidth: 1))
        .environment(\.locale, Locale(identifier: "sw"))
        .accessibilityElement(children: .combine)
    }
}
