import SwiftUI

/// The one motion vocabulary of the app (002 contracts/motion-and-surfaces.md §1). Every spring is
/// critically damped: nothing in this flow is thrown or flicked, so nothing overshoots (FR-005).
/// No other file holds a literal animation or duration, except the hold-to-end fill.
enum Motion {
    enum Token: Sendable, CaseIterable {
        case standard, quick, lamp, reducedFade
    }

    /// Prompt entry and exit, hint nudges, step advances.
    static var standard: Animation { .spring(response: standardResponse, dampingFraction: damping) }
    /// Press feedback, selection fill, badge opacity.
    static var quick: Animation { .spring(response: quickResponse, dampingFraction: damping) }
    /// Every reduced equivalent when Reduce Motion is on: opacity only.
    static var reducedFade: Animation { .easeInOut(duration: reducedFadeSeconds) }

    /// The lamp switch (renderer-driven) and full-screen calm cross-fades.
    static let lamp = RendererTiming(seconds: 0.8, reducedSeconds: 0.4)
    /// The one-time fingertip → wrist glow spread.
    static let glowSpread = RendererTiming(seconds: 1.5, reducedSeconds: 0)

    static let standardResponse = 0.35
    static let quickResponse = 0.2
    static let reducedFadeSeconds = 0.2
    static let damping = 1.0

    /// The token's animation, or its reduced equivalent when Reduce Motion is on.
    static func animation(_ token: Token, reduceMotion: Bool) -> Animation {
        switch token {
        case .standard: reduceMotion ? reducedFade : standard
        case .quick: reduceMotion ? reducedFade : quick
        case .lamp: lamp.animation(reduceMotion: reduceMotion)
        case .reducedFade: reducedFade
        }
    }
}

/// A timing the renderer runs itself (it cannot use SwiftUI animations), with its Reduce Motion
/// value. As a SwiftUI animation it is a smoothstep curve; the reduced version is linear.
struct RendererTiming: Sendable, Equatable {
    let seconds: Double
    let reducedSeconds: Double

    func seconds(reduceMotion: Bool) -> Double {
        reduceMotion ? reducedSeconds : seconds
    }

    /// `timingCurve(1/3, 0, 2/3, 1)` is exactly smoothstep.
    func animation(reduceMotion: Bool = false) -> Animation {
        reduceMotion
            ? .linear(duration: reducedSeconds)
            : .timingCurve(1.0 / 3, 0, 2.0 / 3, 1, duration: seconds)
    }
}
