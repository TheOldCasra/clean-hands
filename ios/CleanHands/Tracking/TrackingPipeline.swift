import CoreVideo
import Foundation
import QuartzCore

/// Runs the hand tracker on the newest camera frame only, then settles identity, smooths every
/// joint, fills in low-confidence joints, and classifies palm/back (research R5, R8).
final class TrackingPipeline: @unchecked Sendable {
    struct Output: Sendable {
        var frame: HandFrame
        /// Non-nil when the face guard's state changed on this frame.
        var faceVisibleChanged: Bool?
        var trackingSeconds: Double
        /// Median brightness of the hands, for the even-exposure gain (research R6).
        var meanLuma: Float?
    }

    private let tracker: HandTracker
    private let faceGuard = FaceGuard()
    private let queue = DispatchQueue(label: "cleanhands.tracking", qos: .userInteractive)
    private let lock = NSLock()
    private var busy = false

    private var setup: CameraSetup
    private var identity = HandIdentity()
    private var filters: [Int: [OneEuroFilter]] = [:]
    private var classifiers: [Int: SurfaceClassifier] = [:]
    private var lastJoints: [Int: [JointPoint]] = [:]

    /// Joints below this confidence are replaced by the previous value or their neighbours.
    var minConfidence: Float = 0.3

    init(tracker: HandTracker, setup: CameraSetup) {
        self.tracker = tracker
        self.setup = setup
        identity.mirrored = setup.mirrorsVideo
    }

    /// Submits a frame; it is dropped if the previous one is still being processed.
    func submit(_ pixelBuffer: CVPixelBuffer, at time: Double, completion: @escaping @Sendable (Output) -> Void) {
        let accepted = lock.withLock {
            guard !busy else { return false }
            busy = true
            return true
        }
        guard accepted else { return }
        nonisolated(unsafe) let buffer = pixelBuffer
        queue.async { [self] in
            let output = process(buffer, at: time)
            lock.withLock { busy = false }
            completion(output)
        }
    }

    /// Processes one frame synchronously. Used directly by the replay harness.
    func process(_ pixelBuffer: CVPixelBuffer, at time: Double) -> Output {
        let start = CACurrentMediaTime()
        let raw = (try? tracker.detect(in: pixelBuffer)) ?? []
        let size = SIMD2(Float(CVPixelBufferGetWidth(pixelBuffer)), Float(CVPixelBufferGetHeight(pixelBuffer)))
        let frame = HandFrame(timestamp: time, imageSize: size, hands: settle(raw, imageWidth: size.x, at: time))
        let faceChanged = faceGuard.check(pixelBuffer, at: time)
        return Output(frame: frame, faceVisibleChanged: faceChanged, trackingSeconds: CACurrentMediaTime() - start,
                      meanLuma: Exposure.meanLuma(of: pixelBuffer, hands: frame.hands))
    }

    func reset(setup: CameraSetup? = nil) {
        queue.sync {
            if let setup {
                self.setup = setup
                identity.mirrored = setup.mirrorsVideo
            }
            identity.reset()
            filters = [:]
            classifiers = [:]
            lastJoints = [:]
            faceGuard.reset()
        }
    }

    private func settle(_ raw: [RawHand], imageWidth: Float, at time: Double) -> [TrackedHand] {
        let assignments = identity.assign(raw, imageWidth: imageWidth)
        var hands: [TrackedHand] = []
        var seen = Set<Int>()

        for (hand, assignment) in zip(raw, assignments) {
            let id = assignment.id
            seen.insert(id)
            if assignment.isNew {
                filters[id] = Array(repeating: OneEuroFilter(), count: Joint.count)
                classifiers[id] = SurfaceClassifier(setup: setup)
                lastJoints[id] = nil
            }
            var joints = fillLowConfidence(hand.joints, previous: lastJoints[id])
            for i in 0..<Joint.count {
                joints[i].position = filters[id]![i].filter(joints[i].position, at: time)
            }
            lastJoints[id] = joints
            let surface = classifiers[id]!.classify(joints: joints, handedness: assignment.handedness, at: time)
            hands.append(TrackedHand(
                id: id,
                chirality: hand.chirality,
                handedness: assignment.handedness,
                joints: joints,
                surface: surface,
                scale: TrackedHand.scale(of: joints)
            ))
        }

        for id in filters.keys where !seen.contains(id) {
            filters[id] = nil
            classifiers[id] = nil
            lastJoints[id] = nil
        }
        return hands
    }

    /// Replaces low-confidence joints with their last good value, or the midpoint of their
    /// neighbours along the finger.
    private func fillLowConfidence(_ joints: [JointPoint], previous: [JointPoint]?) -> [JointPoint] {
        var result = joints
        for i in 0..<Joint.count where joints[i].confidence < minConfidence {
            if let previous {
                result[i].position = previous[i].position
            } else if i > 0 {
                let base = i % 4 == 1 ? 0 : i - 1
                let next = i % 4 == 0 ? i - 1 : i + 1
                result[i].position = (joints[base].position + joints[next].position) / 2
            }
        }
        return result
    }
}
