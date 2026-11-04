import Foundation

/// The lamp: how the view moves between the camera image (`uvAmount` 0) and the UV look (1),
/// interruptibly (002 contracts/lamp-transition.md §1–§6, research D1–D4).
///
/// `uvAmount` follows a rate-limited ramp smoothed by a critically damped spring, so a reversal
/// starts from the value on screen and keeps its velocity: no jump and no "brick wall".
struct LampTransition: Sendable, Equatable {
    /// Ramp time for a full switch (standard and Reduce Motion).
    static let rampSeconds: Float = 0.7
    static let reducedRampSeconds: Float = 0.6
    /// Response of the smoothing spring (`Motion.quick`).
    static let followerResponse: Float = 0.2
    /// How long the badge interlock takes to let glow through.
    static let interlockSeconds: Float = 0.2
    /// Largest step the integrator takes; a hitch slows the lamp but never enlarges a step.
    static let maxStep: Double = 1.0 / 30

    private(set) var uvTarget: Float = 0
    private(set) var uvLinear: Float = 0
    private(set) var uvAmount: Float = 0
    private(set) var velocity: Float = 0
    /// Progress of the one-time fingertip → wrist spread (FR-004a).
    private(set) var glowReveal: Float = 0
    /// Glow multiplier that follows the badge being fully visible (Principle I by construction).
    private(set) var glowInterlock: Float = 0

    /// Paused or blanked: nothing integrates, and a retarget makes no click.
    var frozen = false
    var reduceMotion = false {
        didSet {
            // A changed setting restarts from the value on screen.
            if reduceMotion != oldValue {
                uvLinear = uvAmount
                velocity = 0
            }
        }
    }
    /// Reported by the UI once the simulation badge is fully opaque.
    var badgeOpaque = false

    /// The badge must be on screen whenever the lamp is on or on its way (FR-003).
    var badgeRequired: Bool { uvTarget == 1 || uvAmount > 0 }
    var settled: Bool { uvAmount == uvTarget && velocity == 0 }
    var spreadPlayed: Bool { glowReveal > 0 }

    /// Moves the lamp toward `target` (0 or 1). Returns true when an animated switch-on starts
    /// (the only moment the click plays, FR-016).
    @discardableResult
    mutating func setTarget(_ target: Float, animated: Bool) -> Bool {
        guard animated else {
            uvTarget = target
            uvLinear = target
            uvAmount = target
            velocity = 0
            return false
        }
        guard target != uvTarget else { return false }
        let fromRest = velocity == 0 && (uvAmount == 0 || uvAmount == 1)
        uvTarget = target
        if fromRest, !reduceMotion, target != uvAmount {
            // Kick: the first frame already changes, so the click and the first changed frame coincide.
            velocity = (target > uvAmount ? 1 : -1) / Self.rampSeconds
        }
        return target == 1 && !frozen
    }

    /// Advances one frame.
    mutating func step(dt rawDt: Double) {
        guard !frozen else { return }
        let dt = Float(min(max(rawDt, 0), Self.maxStep))
        guard dt > 0 else { return }

        let ramp = reduceMotion ? Self.reducedRampSeconds : Self.rampSeconds
        uvLinear += min(max(uvTarget - uvLinear, -dt / ramp), dt / ramp)

        if reduceMotion {
            velocity = (uvLinear - uvAmount) / dt
            uvAmount = uvLinear
        } else {
            // Critically damped follower in closed form (stable at any dt).
            let omega = 2 * Float.pi / Self.followerResponse
            let e = uvAmount - uvLinear
            let j = velocity + omega * e
            let decay = exp(-omega * dt)
            uvAmount = uvLinear + (e + j * dt) * decay
            velocity = (velocity - omega * j * dt) * decay
        }
        uvAmount = min(max(uvAmount, 0), 1)

        if uvLinear == uvTarget, abs(uvAmount - uvTarget) < 0.001, abs(velocity) < 0.01 {
            uvAmount = uvTarget
            velocity = 0
        }

        stepReveal(dt: dt)
        glowInterlock = badgeOpaque ? min(1, glowInterlock + dt / Self.interlockSeconds) : 0
    }

    private mutating func stepReveal(dt: Float) {
        guard glowReveal < 1 else { return }
        let gate = Self.channels(uvAmount, reduceMotion: reduceMotion).gate
        if reduceMotion {
            if gate > 0 { glowReveal = 1 }
        } else if uvTarget == 1, uvAmount >= 0.99 {
            glowReveal = min(1, glowReveal + dt / Float(Motion.glowSpread.seconds))
        } else if glowReveal > 0, gate == 0 {
            // Switched off mid-spread: it counts as played.
            glowReveal = 1
        }
    }

    /// Back to the camera image, ready for a new session (spread not played).
    mutating func reset() {
        let keep = (reduceMotion, badgeOpaque)
        self = LampTransition()
        reduceMotion = keep.0
        badgeOpaque = keep.1
    }

    /// For offscreen renders: a fixed lamp value with the spread and interlock complete.
    static func fixed(uvAmount: Float) -> LampTransition {
        var lamp = LampTransition()
        lamp.uvTarget = uvAmount > 0 ? 1 : 0
        lamp.uvLinear = uvAmount
        lamp.uvAmount = uvAmount
        lamp.glowReveal = 1
        lamp.glowInterlock = 1
        lamp.badgeOpaque = true
        return lamp
    }

    // MARK: - Channels (§3, §4)

    struct Channels: Sendable, Equatable {
        /// Room → background (0 = camera, 1 = black).
        var dark: Float
        /// Camera colour → violet ramp.
        var skin: Float
        /// How much glow is let through.
        var gate: Float
    }

    /// Every channel from `uvAmount`, in order: room and skin first, glow only once both are
    /// fully UV (FR-002). The renderer and the unit tests both use this.
    static func channels(_ a: Float, reduceMotion: Bool) -> Channels {
        // Exact ends, so the full lamp is bit-identical to the 001 UV look.
        if a >= 1 { return Channels(dark: 1, skin: 1, gate: 1) }
        if a <= 0 { return Channels(dark: 0, skin: 0, gate: 0) }
        if reduceMotion {
            let x = min(max(a / 0.65, 0), 1)
            return Channels(dark: x, skin: x, gate: min(max((a - 0.67) / 0.33, 0), 1))
        }
        let x = min(max(a / 0.78, 0), 1)
        return Channels(dark: x + x * x - x * x * x, skin: smoothstep(0.05, 0.78, a), gate: smoothstep(0.80, 1, a))
    }

    // MARK: - Glow spread (§5)

    static let revealWindow: Float = 0.35

    /// 0 at the fingertip front, 1 at the forearm point: when a mark lights during the spread.
    static func revealFactor(order: Float, glowReveal: Float) -> Float {
        guard glowReveal < 1 else { return 1 }
        return smoothstep(0, 1, (glowReveal * (1 + revealWindow) - order) / revealWindow)
    }

    static func smoothstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
        let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }
}
