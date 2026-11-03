import Foundation
@testable import CleanHands

/// Tests run hosted in the app, so the bundled look.json is in the main bundle.
func bundledLook() throws -> LookConfig {
    try LookConfig.load(from: .main)
}

/// Joints of the reference pose (a right palm facing the camera) as tracker points.
func referenceJoints(offset: SIMD2<Float> = .zero) -> [JointPoint] {
    CoverageEstimator.referencePose.map { JointPoint(position: $0 + offset, confidence: 1) }
}

/// The reference pose mirrored horizontally: what a left palm facing the camera looks like.
func mirroredJoints() -> [JointPoint] {
    CoverageEstimator.referencePose.map { JointPoint(position: SIMD2(-$0.x, $0.y), confidence: 1) }
}
