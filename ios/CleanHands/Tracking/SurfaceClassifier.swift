import simd

/// Decides whether the palm or the back of a hand faces the camera (research R5), from the hand's
/// chirality and the winding of the wrist → index knuckle → little-finger knuckle triangle.
struct SurfaceClassifier: Sendable {
    /// A side change must persist this long before the pattern switches.
    var hysteresis: Double = 0.15
    /// Triangle area, relative to scale², below which the hand is seen edge-on.
    var edgeOnThreshold: Float = 0.08
    var setup: CameraSetup

    private var current: Surface?
    private var candidate: Surface?
    private var candidateSince: Double = 0

    init(setup: CameraSetup) {
        self.setup = setup
    }

    /// The side seen in a single frame, without hysteresis. In top-left pixel coordinates a right
    /// palm facing an unmirrored camera has a negative winding.
    static func instantSurface(joints: [JointPoint], handedness: Handedness, setup: CameraSetup, edgeOnThreshold: Float) -> Surface {
        let wrist = joints[Joint.wrist.rawValue].position
        let a = joints[Joint.indexMCP.rawValue].position - wrist
        let b = joints[Joint.littleMCP.rawValue].position - wrist
        let cross = a.x * b.y - a.y * b.x
        let scale = TrackedHand.scale(of: joints)
        guard scale > 0, abs(cross) / (scale * scale) >= edgeOnThreshold else { return .edgeOn }
        var palm = (handedness == .right) == (cross < 0)
        if setup.windingSignFlip { palm.toggle() }
        return palm ? .palm : .back
    }

    mutating func classify(joints: [JointPoint], handedness: Handedness, at time: Double) -> Surface {
        let observed = Self.instantSurface(joints: joints, handedness: handedness, setup: setup, edgeOnThreshold: edgeOnThreshold)
        guard let current else {
            self.current = observed
            return observed
        }
        if observed == current {
            candidate = nil
        } else if observed != candidate {
            candidate = observed
            candidateSince = time
        } else if time - candidateSince >= hysteresis {
            self.current = observed
            candidate = nil
            return observed
        }
        return current
    }

    mutating func reset() {
        current = nil
        candidate = nil
    }
}
