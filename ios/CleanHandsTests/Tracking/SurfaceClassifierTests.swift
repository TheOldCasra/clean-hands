import Testing
import simd
@testable import CleanHands

struct SurfaceClassifierTests {
    /// The reference pose is a right palm facing an unmirrored camera; mirroring it gives a left palm.
    @Test(arguments: CameraSetup.allCases)
    func windingAndChiralityGiveTheSide(setup: CameraSetup) {
        let right = referenceJoints()
        let left = mirroredJoints()
        func side(_ joints: [JointPoint], _ hand: Handedness) -> Surface {
            SurfaceClassifier.instantSurface(joints: joints, handedness: hand, setup: setup, edgeOnThreshold: 0.08)
        }
        // A mirrored image mirrors both the winding and the reported chirality, so the answer
        // does not depend on the setup.
        #expect(side(right, .right) == .palm)
        #expect(side(left, .left) == .palm)
        #expect(side(right, .left) == .back)
        #expect(side(left, .right) == .back)
    }

    @Test func edgeOnHandIsDetected() {
        // Squash the hand sideways until the wrist–knuckle triangle almost vanishes.
        let squashed = CoverageEstimator.referencePose.map { JointPoint(position: SIMD2($0.x * 0.05, $0.y), confidence: 1) }
        #expect(SurfaceClassifier.instantSurface(joints: squashed, handedness: .right, setup: .overheadRear, edgeOnThreshold: 0.08) == .edgeOn)
    }

    @Test func sideChangeMustPersistBeforeSwitching() {
        var classifier = SurfaceClassifier(setup: .overheadRear)
        let palm = referenceJoints()
        let back = mirroredJoints() // right hand seen from the back
        #expect(classifier.classify(joints: palm, handedness: .right, at: 0) == .palm)
        #expect(classifier.classify(joints: back, handedness: .right, at: 0.05) == .palm)
        #expect(classifier.classify(joints: back, handedness: .right, at: 0.15) == .palm)
        #expect(classifier.classify(joints: back, handedness: .right, at: 0.21) == .back)
    }

    @Test func briefFlickerDoesNotSwitch() {
        var classifier = SurfaceClassifier(setup: .overheadRear)
        let palm = referenceJoints()
        let back = mirroredJoints()
        _ = classifier.classify(joints: palm, handedness: .right, at: 0)
        _ = classifier.classify(joints: back, handedness: .right, at: 0.05)
        _ = classifier.classify(joints: palm, handedness: .right, at: 0.10)
        #expect(classifier.classify(joints: back, handedness: .right, at: 0.22) == .palm)
    }
}
