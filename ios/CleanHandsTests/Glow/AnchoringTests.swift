import Testing
import simd
@testable import CleanHands

struct AnchoringTests {
    private let joints = Anchoring.extendedJoints(CoverageEstimator.referencePose, wristExtent: 0.25)
    private let scale: Float = 100

    private func mark(_ anchor: Anchor, size: Float = 0.01) -> GlowMark {
        GlowMark(hand: .right, surface: .palm, region: .fingertip, anchor: anchor, kind: .fleck,
                 size: size, aspect: 1, intensity: 1, hue: 0.5, grainSeed: 0)
    }

    @Test func boneAnchorsResolveInsideTheFinger() {
        var rng = SplitMix64(seed: 1)
        for _ in 0..<2000 {
            let (a, b) = Anchoring.bones[rng.index(Anchoring.bones.count)]
            let anchor = Anchor.bone(a: a, b: b, t: rng.unit(), s: rng.uniform(-0.7...0.7))
            let center = Anchoring.placement(of: mark(anchor), joints: joints, scale: scale).center
            let radius = Anchoring.halfWidth(boneTo: b) * scale
            #expect(CoverageEstimator.distanceToSegment(center, joints[a], joints[b]) <= radius * 0.7 + 1e-3)
        }
    }

    @Test func triangleAnchorsResolveInsideTheirTriangle() {
        var rng = SplitMix64(seed: 2)
        for _ in 0..<2000 {
            let (a, b, c) = Anchoring.palmTriangles[rng.index(4)]
            let r1 = rng.unit().squareRoot(), r2 = rng.unit()
            let anchor = Anchor.triangle(a: a, b: b, c: c, u: 1 - r1, v: r1 * (1 - r2), w: r1 * r2)
            let center = Anchoring.placement(of: mark(anchor), joints: joints, scale: scale).center
            #expect(CoverageEstimator.isInside(center, polygon: [joints[a], joints[b], joints[c]].map { $0 }) ||
                    CoverageEstimator.distanceToSegment(center, joints[a], joints[b]) < 0.01 ||
                    CoverageEstimator.distanceToSegment(center, joints[b], joints[c]) < 0.01 ||
                    CoverageEstimator.distanceToSegment(center, joints[c], joints[a]) < 0.01)
        }
    }

    @Test func marksFollowFingerFlexion() {
        // Bend the index finger at the middle joint: a mark on the outer bone moves with it.
        let anchor = Anchor.bone(a: 7, b: 8, t: 0.5, s: 0)
        let before = Anchoring.placement(of: mark(anchor), joints: joints, scale: scale).center
        var bent = joints
        bent[8] = bent[7] + SIMD2(20, 10)
        let after = Anchoring.placement(of: mark(anchor), joints: bent, scale: scale).center
        #expect(simd_distance(after, (bent[7] + bent[8]) / 2) < 1e-3)
        #expect(simd_distance(before, after) > 5)
    }

    @Test func marksFollowRotationAndTranslation() {
        let anchor = Anchor.triangle(a: 0, b: 9, c: 13, u: 0.3, v: 0.4, w: 0.3)
        let angle: Float = 0.7
        let rotation = simd_float2x2(SIMD2(cos(angle), sin(angle)), SIMD2(-sin(angle), cos(angle)))
        let moved = joints.map { rotation * $0 + SIMD2(300, 120) }
        let before = Anchoring.placement(of: mark(anchor), joints: joints, scale: scale)
        let after = Anchoring.placement(of: mark(anchor), joints: moved, scale: scale)
        #expect(simd_distance(after.center, rotation * before.center + SIMD2(300, 120)) < 1e-2)
        #expect(simd_distance(after.axis, rotation * before.axis) < 1e-4)
    }

    @Test func forearmPointSitsBeyondTheWrist() {
        let wrist = joints[Joint.wrist.rawValue]
        let forearm = joints[Joint.forearm]
        #expect(abs(simd_distance(wrist, forearm) - 25) < 1e-3)
        #expect(forearm.y > wrist.y)
    }
}
