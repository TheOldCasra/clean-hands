import AVFoundation

/// The two physical setups (research R9). Both keep faces out of frame by construction.
enum CameraSetup: String, CaseIterable, Codable, Sendable {
    /// Setup A (default): iPad screen-up on a stand, rear camera looking down at the hands.
    case overheadRear
    /// Setup B: iPad upright, clip-on mirror turning the front camera down to the table.
    case mirrorFront

    var position: AVCaptureDevice.Position {
        switch self {
        case .overheadRear: .back
        case .mirrorFront: .front
        }
    }

    /// The mirror in setup B flips the image, so it is flipped back in software.
    var mirrorsVideo: Bool { self == .mirrorFront }

    /// Calibration of the palm/back winding rule (research R5). Fixed by the on-device check;
    /// both setups start unflipped because a mirrored image also mirrors the reported chirality.
    var windingSignFlip: Bool { false }
}
