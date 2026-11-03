import CoreVideo
import Vision

/// Apple Vision's on-device hand pose model (research R3): pretrained, offline, no model files.
final class VisionHandTracker: HandTracker, @unchecked Sendable {
    private let request: VNDetectHumanHandPoseRequest = {
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 2
        return request
    }()

    private static let jointNames: [VNHumanHandPoseObservation.JointName] = [
        .wrist,
        .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
        .indexMCP, .indexPIP, .indexDIP, .indexTip,
        .middleMCP, .middlePIP, .middleDIP, .middleTip,
        .ringMCP, .ringPIP, .ringDIP, .ringTip,
        .littleMCP, .littlePIP, .littleDIP, .littleTip,
    ]

    func detect(in pixelBuffer: CVPixelBuffer) throws -> [RawHand] {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        try handler.perform([request])
        let width = Float(CVPixelBufferGetWidth(pixelBuffer))
        let height = Float(CVPixelBufferGetHeight(pixelBuffer))

        return (request.results ?? []).compactMap { observation in
            guard let points = try? observation.recognizedPoints(.all) else { return nil }
            let joints = Self.jointNames.map { name -> JointPoint in
                guard let point = points[name] else { return JointPoint(position: .zero, confidence: 0) }
                // Vision uses a lower-left origin; the app uses top-left pixel coordinates.
                return JointPoint(
                    position: SIMD2(Float(point.location.x) * width, (1 - Float(point.location.y)) * height),
                    confidence: point.confidence
                )
            }
            let chirality: Chirality = switch observation.chirality {
            case .left: .left
            case .right: .right
            default: .unknown
            }
            return RawHand(chirality: chirality, joints: joints)
        }
    }
}
