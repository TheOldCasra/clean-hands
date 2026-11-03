import simd

/// CPU estimate of how much of a hand glows, using the same shapes and grain as the GPU. Used by
/// the coverage unit tests and comparable to `tools/measure_glow.py` on screenshots.
enum CoverageEstimator {
    struct Result {
        var coverage: Float
        /// Glow share of hand pixels in each fifth of the hand's height, fingertips first.
        var fifths: [Float]
    }

    /// Coverage above which a pixel reads as glowing in `measure_glow.py` (green dominant, g > 0.3).
    static let glowThreshold: Float = 0.3

    /// A right hand, open palm facing the camera, fingers up, scale 100 px (top-left origin).
    static let referencePose: [SIMD2<Float>] = [
        SIMD2(0, 0),
        SIMD2(28, -20), SIMD2(52, -45), SIMD2(70, -68), SIMD2(84, -90),
        SIMD2(30, -95), SIMD2(38, -140), SIMD2(42, -168), SIMD2(45, -192),
        SIMD2(0, -100), SIMD2(0, -150), SIMD2(0, -181), SIMD2(0, -206),
        SIMD2(-26, -95), SIMD2(-32, -141), SIMD2(-36, -170), SIMD2(-39, -193),
        SIMD2(-48, -85), SIMD2(-60, -120), SIMD2(-67, -142), SIMD2(-72, -162),
    ]

    /// Whether a point lies on the hand: finger and wrist capsules plus the palm outline.
    static func isOnHand(_ p: SIMD2<Float>, joints: [SIMD2<Float>], scale: Float) -> Bool {
        for (a, b) in Anchoring.bones {
            let radius = Anchoring.halfWidth(boneTo: b) * scale
            if distanceToSegment(p, joints[a], joints[b]) <= radius { return true }
        }
        return isInside(p, polygon: Anchoring.palmOutline.map { joints[$0] })
    }

    static func distanceToSegment(_ p: SIMD2<Float>, _ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float {
        let ab = b - a
        let t = min(max(simd_dot(p - a, ab) / max(simd_length_squared(ab), 1e-6), 0), 1)
        return simd_distance(p, a + ab * t)
    }

    static func isInside(_ p: SIMD2<Float>, polygon: [SIMD2<Float>]) -> Bool {
        var inside = false
        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let (a, b) = (polygon[i], polygon[j])
            if (a.y > p.y) != (b.y > p.y), p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x {
                inside.toggle()
            }
            j = i
        }
        return inside
    }

    static func coverage(at p: SIMD2<Float>, marks: [(GlowMark, MarkPlacement)], scale: Float, config: LookConfig) -> Float {
        var total: Float = 0
        for (mark, placement) in marks {
            let local = placement.local(p)
            guard abs(local.x) < 1, abs(local.y) < 1 else { continue }
            let offset = p - placement.center
            let handOffset = SIMD2(simd_dot(offset, placement.axis), simd_dot(offset, placement.perpendicular)) / scale
            let grain = MarkShape.grain(offsetInScales: handOffset, grainScale: Float(config.glow.grain.scale),
                                        strength: Float(config.glow.grain.strength), seed: mark.grainSeed)
            total += MarkShape.value(kind: mark.kind, local: local, intensity: mark.intensity) * grain
        }
        return min(total, 1)
    }

    /// Measures one side of one hand in the reference pose on a pixel grid.
    static func measure(pattern: GlowPattern, hand: Handedness, side: PatternSide, config: LookConfig,
                        joints: [SIMD2<Float>] = referencePose, step: Float = 1) -> Result {
        let scale: Float = simd_distance(joints[0], joints[Joint.middleMCP.rawValue])
        let extended = Anchoring.extendedJoints(joints, wristExtent: Float(config.pattern.wristExtent))
        let marks = pattern.marks(hand: hand, side: side).map { ($0, Anchoring.placement(of: $0, joints: extended, scale: scale)) }

        let minP = extended.reduce(SIMD2<Float>(repeating: .infinity)) { simd_min($0, $1) } - scale * 0.4
        let maxP = extended.reduce(SIMD2<Float>(repeating: -.infinity)) { simd_max($0, $1) } + scale * 0.4

        var rows: [(y: Float, hand: Int, glow: Int)] = []
        var y = minP.y
        while y <= maxP.y {
            var handCount = 0
            var glowCount = 0
            var x = minP.x
            while x <= maxP.x {
                let p = SIMD2(x, y)
                if isOnHand(p, joints: extended, scale: scale) {
                    handCount += 1
                    if coverage(at: p, marks: marks, scale: scale, config: config) >= glowThreshold { glowCount += 1 }
                }
                x += step
            }
            if handCount > 0 { rows.append((y, handCount, glowCount)) }
            y += step
        }

        let totalHand = rows.reduce(0) { $0 + $1.hand }
        let totalGlow = rows.reduce(0) { $0 + $1.glow }
        let top = rows.first?.y ?? 0
        let bottom = rows.last?.y ?? 0
        var fifths: [Float] = []
        for i in 0..<5 {
            let lo = top + (bottom - top) * Float(i) / 5
            let hi = top + (bottom - top) * Float(i + 1) / 5
            let band = rows.filter { $0.y >= lo && (i == 4 ? $0.y <= hi : $0.y < hi) }
            let h = band.reduce(0) { $0 + $1.hand }
            let g = band.reduce(0) { $0 + $1.glow }
            fifths.append(h > 0 ? Float(g) / Float(h) : 0)
        }
        return Result(coverage: totalHand > 0 ? Float(totalGlow) / Float(totalHand) : 0, fifths: fifths)
    }
}
