import CoreVideo
import Foundation
import Vision

/// Backup for Principle VII: if a face enters the frame, the app blanks the camera and pauses.
/// Runs about twice per second on the tracking queue.
final class FaceGuard: @unchecked Sendable {
    private let request = VNDetectFaceRectanglesRequest()
    private let interval: Double
    private var lastCheck = -Double.infinity
    private(set) var faceVisible = false

    init(interval: Double = 0.5) {
        self.interval = interval
    }

    /// Returns the new state when it changes, otherwise nil.
    func check(_ pixelBuffer: CVPixelBuffer, at time: Double) -> Bool? {
        guard time - lastCheck >= interval else { return nil }
        lastCheck = time
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        guard (try? handler.perform([request])) != nil else { return nil }
        let visible = !(request.results ?? []).isEmpty
        guard visible != faceVisible else { return nil }
        faceVisible = visible
        return visible
    }

    func reset() {
        faceVisible = false
        lastCheck = -Double.infinity
    }
}
