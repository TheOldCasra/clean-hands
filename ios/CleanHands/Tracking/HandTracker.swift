import CoreVideo
import simd

/// The 21 hand joints, in the order every tracker reports them (wrist, then thumb to little finger,
/// base to tip). Index 21 is a virtual forearm point used for wrist marks (see `Anchoring`).
enum Joint: Int, CaseIterable, Sendable {
    case wrist = 0
    case thumbCMC, thumbMP, thumbIP, thumbTip
    case indexMCP, indexPIP, indexDIP, indexTip
    case middleMCP, middlePIP, middleDIP, middleTip
    case ringMCP, ringPIP, ringDIP, ringTip
    case littleMCP, littlePIP, littleDIP, littleTip

    static let count = 21
    /// Virtual joint: the wrist pushed toward the forearm by `pattern.wristExtent`.
    static let forearm = 21
}

enum Chirality: String, Sendable {
    case left, right, unknown
}

/// Which hand a pattern belongs to, once identity is settled (`HandIdentity`).
enum Handedness: String, CaseIterable, Codable, Sendable {
    case left, right
}

enum Surface: String, Codable, Sendable {
    case palm, back, edgeOn
}

struct JointPoint: Sendable, Equatable {
    var position: SIMD2<Float>
    var confidence: Float
}

/// A hand as a tracker reports it, before identity, smoothing, and surface classification.
struct RawHand: Sendable {
    var chirality: Chirality
    /// 21 joints in buffer pixel coordinates (origin top-left, y down).
    var joints: [JointPoint]
}

/// A tracked hand after the pipeline (data-model.md, `TrackedHand`).
struct TrackedHand: Sendable, Identifiable {
    var id: Int
    var chirality: Chirality
    var handedness: Handedness
    /// 21 joints in buffer pixel coordinates, smoothed with the One Euro filter.
    var joints: [JointPoint]
    var surface: Surface
    /// Wrist to middle-finger knuckle distance, in pixels.
    var scale: Float

    func point(_ joint: Joint) -> SIMD2<Float> { joints[joint.rawValue].position }

    static func scale(of joints: [JointPoint]) -> Float {
        simd_distance(joints[Joint.wrist.rawValue].position, joints[Joint.middleMCP.rawValue].position)
    }
}

/// The output of the tracking pipeline for one camera frame (data-model.md, `HandFrame`).
struct HandFrame: Sendable {
    var timestamp: Double
    var imageSize: SIMD2<Float>
    var hands: [TrackedHand]

    static let empty = HandFrame(timestamp: 0, imageSize: .zero, hands: [])
}

/// Swappable hand tracker (research R3). Vision is the first adapter; MediaPipe or a custom model
/// plug in here if gate 2 fails.
protocol HandTracker: AnyObject, Sendable {
    /// Detects up to two hands in an upright camera frame. Called on the tracking queue.
    func detect(in pixelBuffer: CVPixelBuffer) throws -> [RawHand]
}
