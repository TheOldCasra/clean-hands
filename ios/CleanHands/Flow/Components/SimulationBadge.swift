import SwiftUI

/// Marks the glow as a simulation (FR-008, Principle I): a lamp icon with the Swahili label.
/// Always a solid chip, identical on every iPad and quality level (002 FR-026).
/// `ParticipantRootView` decides when it shows.
struct SimulationBadge: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "lamp.desk.fill")
                .font(.system(size: 26, weight: .semibold))
            Text("Simulation")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .tracking(0.2)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Capsule().fill(Color(white: 0.08)))
        .overlay(Capsule().strokeBorder(.white, lineWidth: 1))
        .environment(\.locale, Locale(identifier: "sw"))
        .accessibilityElement(children: .combine)
    }
}
