import Foundation

/// How much of the pattern is left, per hand, side, and region (data-model.md, `FadeState`), plus
/// each tracked hand's appear/disappear fade. Never saved: every session starts from full glow.
struct FadeState: Sendable {
    struct Key: Hashable, Sendable {
        var hand: Handedness
        var side: PatternSide
        var region: GlowRegion
    }

    private var multipliers: [Key: Float] = [:]
    /// Presence of each tracked hand id, 0 (gone) to 1 (fully shown).
    private(set) var presence: [Int: Float] = [:]

    var fadeInSeconds: Double
    var fadeOutSeconds: Double

    init(fadeInMs: Double = 300, fadeOutMs: Double = 250) {
        fadeInSeconds = fadeInMs / 1000
        fadeOutSeconds = fadeOutMs / 1000
    }

    init(config: LookConfig) {
        self.init(fadeInMs: config.fade.fadeInMs, fadeOutMs: config.fade.fadeOutMs)
    }

    func multiplier(hand: Handedness, side: PatternSide, region: GlowRegion) -> Float {
        multipliers[Key(hand: hand, side: side, region: region)] ?? 1
    }

    mutating func setMultiplier(_ value: Float, hand: Handedness, side: PatternSide, region: GlowRegion) {
        multipliers[Key(hand: hand, side: side, region: region)] = min(max(value, 0), 1)
    }

    /// Sets a region to `value` on both hands and both sides.
    mutating func setMultiplier(_ value: Float, region: GlowRegion) {
        for hand in Handedness.allCases {
            for side in PatternSide.allCases {
                setMultiplier(value, hand: hand, side: side, region: region)
            }
        }
    }

    func presence(of id: Int) -> Float { presence[id] ?? 0 }

    /// Fades present hands in and absent hands out. Fully faded-out hands are forgotten.
    mutating func updatePresence(present ids: Set<Int>, dt: Double) {
        for id in ids where presence[id] == nil {
            presence[id] = 0
        }
        for (id, value) in presence {
            if ids.contains(id) {
                presence[id] = min(1, value + Float(dt / fadeInSeconds))
            } else {
                let next = value - Float(dt / fadeOutSeconds)
                presence[id] = next > 0 ? next : nil
            }
        }
    }

    var anyVisible: Bool { presence.values.contains { $0 > 0 } }

    mutating func resetPresence() {
        presence = [:]
    }
}
