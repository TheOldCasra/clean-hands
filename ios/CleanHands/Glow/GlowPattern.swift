/// Regions of the hand, in the vocabulary of research R7 and data-model.md.
enum GlowRegion: String, CaseIterable, Codable, Sendable {
    case fingertip, thumb, interdigital, dorsalFinger, backOfHand, palmEdge, palm, wrist
}

enum MarkKind: String, CaseIterable, Codable, Sendable {
    /// Near-solid coverage of a fingertip pad; exactly one per finger and thumb, per side.
    case cap
    /// Elongated smudge along a finger bone.
    case streak
    /// Small grainy speck.
    case fleck
    /// Large, soft, low-coverage area.
    case patch
}

/// The pattern side. A hand seen edge-on shows no pattern, so `edgeOn` never appears here.
enum PatternSide: String, CaseIterable, Codable, Sendable {
    case palm, back
}

/// Where a mark sits, in the hand's own coordinates (data-model.md, `Anchor`).
enum Anchor: Equatable, Codable, Sendable {
    /// A point along the bone from joint `a` to joint `b` at `t ∈ [0, 1]`, offset sideways by
    /// `s ∈ [-0.7, 0.7]` finger half-widths, which keeps the mark inside the finger.
    case bone(a: Int, b: Int, t: Float, s: Float)
    /// A point inside the triangle of joints `a`, `b`, `c`, with barycentric weights `u + v + w = 1`.
    case triangle(a: Int, b: Int, c: Int, u: Float, v: Float, w: Float)
}

/// One mark of the simulated coating (data-model.md, `GlowMark`).
struct GlowMark: Equatable, Codable, Sendable {
    var hand: Handedness
    var surface: PatternSide
    var region: GlowRegion
    var anchor: Anchor
    var kind: MarkKind
    /// Half-width relative to the hand's scale. For caps, the share of the fingertip bone covered.
    var size: Float
    /// Half-length over half-width.
    var aspect: Float
    /// 0…1
    var intensity: Float
    /// Position within the glow palette in look.json, 0…1.
    var hue: Float
    /// Offsets the grain so neighbouring marks do not repeat it.
    var grainSeed: UInt32
}

/// The simulated contamination for one participant, generated from her seed (FR-006).
struct GlowPattern: Equatable, Sendable {
    var seed: UInt64
    var marks: [GlowMark]

    func marks(hand: Handedness, side: PatternSide) -> [GlowMark] {
        marks.filter { $0.hand == hand && $0.surface == side }
    }
}
