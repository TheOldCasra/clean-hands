import SwiftUI

/// The one path for participant prompts (002 motion-and-surfaces §2.3, research D6): appear in
/// place (opacity, scale 0.92 → 1) and leave by the exact reverse. Entries never travel, so the
/// only directional movement on screen is a hint. Opacity only with Reduce Motion.
extension AnyTransition {
    static func prompt(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.92))
    }
}

extension View {
    /// Inserts and removes this view along the prompt path, animated with `Motion.standard`.
    func promptTransition(reduceMotion: Bool) -> some View {
        transition(.prompt(reduceMotion: reduceMotion))
    }
}
