import SwiftUI

/// How heavy a glass surface reads: the facilitator strip is a bar; small facilitator chips are
/// lighter. The simulation badge is never glass (FR-026).
enum GlassProminence: Sendable {
    case bar, chip
}

extension EnvironmentValues {
    /// The renderer's current quality level; glass falls back to solid below `.high` (FR-021).
    @Entry var qualityLevel: QualityLevel = .high
}

/// Dark translucent chrome over the moving camera image, with an instant solid fallback
/// (002 motion-and-surfaces §2.2, research D10). The first matching condition wins.
private struct GlassSurfaceModifier<S: InsettableShape>: ViewModifier {
    var shape: S
    var prominence: GlassProminence

    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.qualityLevel) private var quality

    func body(content: Content) -> some View {
        content
            .background { fill }
            .overlay { edge }
            .shadow(color: prominence == .bar ? .black.opacity(0.25) : .clear, radius: 8, y: 2)
            .environment(\.colorScheme, .dark)
    }

    @ViewBuilder private var fill: some View {
        if contrast == .increased {
            shape.fill(Color(white: 0.06))
        } else if reduceTransparency || quality < .high {
            shape.fill(Color(white: 0.10))
        } else {
            shape.fill(.thinMaterial).overlay(shape.fill(.black.opacity(0.3)))
        }
    }

    @ViewBuilder private var edge: some View {
        if contrast == .increased {
            shape.strokeBorder(.white, lineWidth: 2)
        } else if reduceTransparency {
            shape.strokeBorder(.white.opacity(0.6), lineWidth: 1)
        } else {
            // Light catching the top edge of the material.
            shape.strokeBorder(
                LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0)], startPoint: .top, endPoint: .center),
                lineWidth: 1
            )
        }
    }
}

extension View {
    func glassSurface<S: InsettableShape>(_ shape: S, prominence: GlassProminence = .bar) -> some View {
        modifier(GlassSurfaceModifier(shape: shape, prominence: prominence))
    }
}
