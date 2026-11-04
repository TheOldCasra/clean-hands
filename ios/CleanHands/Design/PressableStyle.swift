import SwiftUI

/// Feedback on touch-down, action on release (002 motion-and-surfaces §2.1, research D8). The
/// highlight shows in the first frame with no animation; only the scale uses a spring. Being a
/// `ButtonStyle`, it keeps the system's act-on-release, drag-off cancel, and VoiceOver behaviour.
struct PressableStyle<S: Shape>: ButtonStyle {
    var shape: S
    var highlight: Color = .white.opacity(0.22)
    var minHitSize: CGFloat = 44

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(minWidth: minHitSize, minHeight: minHitSize)
            .contentShape(shape)
            .overlay {
                // Unanimated on press, so it is visible in the first frame (SC-003).
                shape.fill(highlight)
                    .opacity(configuration.isPressed ? 1 : 0)
                    .allowsHitTesting(false)
                    .animation(configuration.isPressed ? nil : Motion.animation(.quick, reduceMotion: reduceMotion),
                               value: configuration.isPressed)
            }
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(reduceMotion ? nil : Motion.quick, value: configuration.isPressed)
    }
}

extension PressableStyle where S == Capsule {
    init(highlight: Color = .white.opacity(0.22), minHitSize: CGFloat = 44) {
        self.init(shape: Capsule(), highlight: highlight, minHitSize: minHitSize)
    }
}
