import simd

/// The hand light pool (research R4): the hand shape built from joints only (a capsule per finger
/// bone, the wrist toward the forearm, and the palm outline), dilated and blurred in the shader so
/// the hands look lit by a lamp on a black background. Its tight core also masks the glow.
struct LightPool {
    /// Matches `Capsule` in Shaders.metal.
    struct Capsule {
        var ab: SIMD4<Float>
        var params: SIMD4<Float>
    }

    /// Matches `PalmOutline` in Shaders.metal.
    struct PalmOutline {
        var p01: SIMD4<Float>
        var p23: SIMD4<Float>
        var p45: SIMD4<Float>
        var params: SIMD4<Float>
    }

    /// Matches `PoolUniforms` in Shaders.metal.
    struct Uniforms {
        var info: SIMD4<Float>
        var size: SIMD4<Float>
    }

    var capsules: [Capsule] = []
    var palms: [PalmOutline] = []

    /// Builds the shapes for each hand, with its presence fade (0…1).
    init(hands: [(hand: TrackedHand, presence: Float)], wristExtent: Float) {
        for (index, entry) in hands.prefix(2).enumerated() {
            let hand = entry.hand
            let joints = Anchoring.extendedJoints(hand.joints.map(\.position), wristExtent: wristExtent)
            for (a, b) in Anchoring.bones {
                let radius = Anchoring.halfWidth(boneTo: b) * hand.scale
                capsules.append(Capsule(
                    ab: SIMD4(joints[a].x, joints[a].y, joints[b].x, joints[b].y),
                    params: SIMD4(radius, hand.scale, Float(index), 0)
                ))
            }
            let o = Anchoring.palmOutline.map { joints[$0] }
            palms.append(PalmOutline(
                p01: SIMD4(o[0].x, o[0].y, o[1].x, o[1].y),
                p23: SIMD4(o[2].x, o[2].y, o[3].x, o[3].y),
                p45: SIMD4(o[4].x, o[4].y, o[5].x, o[5].y),
                params: SIMD4(hand.scale, entry.presence, 0, 0)
            ))
        }
    }

    func uniforms(imageSize: SIMD2<Float>, config: LookConfig) -> Uniforms {
        let pool = config.uvView.lightPool
        return Uniforms(
            info: SIMD4(Float(capsules.count), Float(palms.count), Float(pool.dilate), Float(pool.blur)),
            size: SIMD4(imageSize.x, imageSize.y, Float(pool.falloff), 0)
        )
    }
}
