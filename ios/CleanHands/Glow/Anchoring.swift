import simd

/// Where a mark lands on a tracked hand: its centre, orientation, and extent, in pixels.
struct MarkPlacement: Sendable {
    var center: SIMD2<Float>
    /// Unit vector along the mark's length (toward the fingertip for finger marks).
    var axis: SIMD2<Float>
    var halfLength: Float
    var halfWidth: Float

    var perpendicular: SIMD2<Float> { SIMD2(-axis.y, axis.x) }

    /// Mark-local coordinates of a point, normalized by the half extents.
    func local(_ point: SIMD2<Float>) -> SIMD2<Float> {
        let d = point - center
        return SIMD2(simd_dot(d, axis) / halfLength, simd_dot(d, perpendicular) / halfWidth)
    }
}

/// Turns anchors into positions on a hand, so marks follow movement, rotation, and finger
/// flexion (FR-003).
enum Anchoring {
    /// Half-width of each finger relative to the hand's scale.
    static let fingerHalfWidth: [Float] = [0.12, 0.10, 0.105, 0.10, 0.085]
    static let wristHalfWidth: Float = 0.32

    /// Finger bones as joint pairs, base to tip, plus the wrist toward the forearm.
    static let bones: [(Int, Int)] = [
        (1, 2), (2, 3), (3, 4),
        (5, 6), (6, 7), (7, 8),
        (9, 10), (10, 11), (11, 12),
        (13, 14), (14, 15), (15, 16),
        (17, 18), (18, 19), (19, 20),
        (Joint.wrist.rawValue, Joint.forearm),
    ]

    /// The palm (or back) outline: wrist, thumb base, and the four knuckles.
    static let palmOutline: [Int] = [0, 1, 5, 9, 13, 17]

    /// Triangles covering the palm and back of the hand.
    static let palmTriangles: [(Int, Int, Int)] = [(0, 1, 5), (0, 5, 9), (0, 9, 13), (0, 13, 17)]

    /// Half-width, relative to scale, of the bone that ends at joint `b`.
    static func halfWidth(boneTo b: Int) -> Float {
        if b == Joint.forearm || b == Joint.wrist.rawValue { return wristHalfWidth }
        return fingerHalfWidth[(b - 1) / 4]
    }

    /// The 21 joints plus the virtual forearm point `wristExtent` scales beyond the wrist.
    static func extendedJoints(_ joints: [SIMD2<Float>], wristExtent: Float) -> [SIMD2<Float>] {
        let wrist = joints[Joint.wrist.rawValue]
        let middle = joints[Joint.middleMCP.rawValue]
        return joints + [wrist + (wrist - middle) * wristExtent]
    }

    /// Joint-chain distance from the fingertips: tips 0, then 1/3 per joint to the knuckles (1),
    /// the wrist (2), and the forearm point (2 + `wristExtent`). Pose-independent (002 lamp §5).
    static func chainDistance(_ joint: Int, wristExtent: Float) -> Float {
        if joint == Joint.wrist.rawValue { return 2 }
        if joint == Joint.forearm { return 2 + wristExtent }
        return Float(4 - (joint - 1) % 4 - 1) / 3
    }

    /// When a mark lights during the glow spread: 0 at the fingertip front, 1 at the forearm point.
    static func revealOrder(of mark: GlowMark, wristExtent: Float) -> Float {
        let d: Float
        switch mark.anchor {
        case let .bone(a, b, t, _):
            let da = chainDistance(a, wristExtent: wristExtent)
            d = da + (chainDistance(b, wristExtent: wristExtent) - da) * t
        case let .triangle(a, b, c, u, v, w):
            d = u * chainDistance(a, wristExtent: wristExtent) + v * chainDistance(b, wristExtent: wristExtent)
                + w * chainDistance(c, wristExtent: wristExtent)
        }
        return min(max(d / (2 + wristExtent), 0), 1)
    }

    static func placement(of mark: GlowMark, joints: [SIMD2<Float>], scale: Float) -> MarkPlacement {
        switch mark.anchor {
        case let .bone(a, b, t, s):
            let start = joints[a]
            let end = joints[b]
            let length = max(simd_distance(start, end), 1e-3)
            let axis = (end - start) / length
            let perpendicular = SIMD2(-axis.y, axis.x)
            let fingerHalf = halfWidth(boneTo: b) * scale
            let center = start + (end - start) * t + perpendicular * (s * fingerHalf)
            if mark.kind == .cap {
                // A cap covers the fingertip pad: the outer `size` share of the last bone, the
                // rounded tip beyond the tip joint, and a fading tail toward the middle joint.
                let from = end - axis * ((mark.size + 0.4) * length)
                let to = end + axis * (0.8 * fingerHalf)
                return MarkPlacement(center: (from + to) / 2, axis: axis, halfLength: simd_distance(from, to) / 2, halfWidth: fingerHalf * 0.95)
            }
            return MarkPlacement(center: center, axis: axis, halfLength: mark.size * mark.aspect * scale, halfWidth: mark.size * scale)
        case let .triangle(a, b, c, u, v, w):
            let pa: SIMD2<Float> = joints[a] * u
            let pb: SIMD2<Float> = joints[b] * v
            let pc: SIMD2<Float> = joints[c] * w
            let center = pa + pb + pc
            let up = joints[Joint.middleMCP.rawValue] - joints[Joint.wrist.rawValue]
            let axis = simd_length(up) > 0 ? simd_normalize(up) : SIMD2(0, -1)
            return MarkPlacement(center: center, axis: axis, halfLength: mark.size * mark.aspect * scale, halfWidth: mark.size * scale)
        }
    }
}
