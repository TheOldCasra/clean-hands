import SwiftUI

/// Marks the glow as a simulation (FR-008, Principle I): a small, quiet Swahili label
/// ("Uigaji"), identical on every iPad and quality level (002 FR-026).
/// `ParticipantRootView` decides when it shows.
struct SimulationBadge: View {
    var body: some View {
        Text("Simulation")
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .tracking(0.3)
            .foregroundStyle(.white.opacity(0.7))
            .shadow(color: .black.opacity(0.8), radius: 3)
            .environment(\.locale, Locale(identifier: "sw"))
    }
}
