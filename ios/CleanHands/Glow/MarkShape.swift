import simd

/// The coverage a single mark adds at a point. `Shaders.metal` (`markValue`, `grainHash`) mirrors
/// this exactly, so the CPU coverage estimate and unit tests describe what the GPU draws.
enum MarkShape {
    static func smoothstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
        let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }

    /// Coverage before grain, for mark-local coordinates normalized by the half extents.
    static func value(kind: MarkKind, local: SIMD2<Float>, intensity: Float) -> Float {
        let d = simd_length(local)
        switch kind {
        case .cap:
            // Near-solid on the pad (a rounded box, not an ellipse), fading toward the middle of the finger.
            let q = local * local
            let box = sqrt(sqrt(q.x * q.x + q.y * q.y))
            return intensity * (1 - smoothstep(0.8, 1.0, box)) * (0.35 + 0.65 * smoothstep(-1.0, -0.3, local.x))
        case .streak:
            return intensity * (1 - smoothstep(0.3, 1.0, d))
        case .fleck:
            return intensity * (1 - smoothstep(0.5, 1.0, d))
        case .patch:
            return intensity * (1 - smoothstep(0.0, 1.0, d))
        }
    }

    /// Integer hash to [0, 1), identical in Metal.
    static func grainHash(_ x: Int32, _ y: Int32, _ seed: UInt32) -> Float {
        var h = UInt32(bitPattern: x) &* 0x8DA6_B343 ^ UInt32(bitPattern: y) &* 0xD816_3841 ^ seed &* 0xCB1A_B31F
        h ^= h >> 16
        h &*= 0x7FEB_352D
        h ^= h >> 15
        h &*= 0x846C_A68B
        h ^= h >> 16
        return Float(h >> 8) / Float(1 << 24)
    }

    /// Powdery break-up, fixed to the hand: the grain cell comes from the offset to the mark's
    /// centre in the hand's own frame, so it moves with the hand and never swims.
    static func grain(offsetInScales: SIMD2<Float>, grainScale: Float, strength: Float, seed: UInt32) -> Float {
        let cell = SIMD2<Int32>(Int32((offsetInScales.x / grainScale).rounded(.down)), Int32((offsetInScales.y / grainScale).rounded(.down)))
        let g = grainHash(cell.x, cell.y, seed)
        return (1 - strength) + strength * 1.6 * g
    }
}
