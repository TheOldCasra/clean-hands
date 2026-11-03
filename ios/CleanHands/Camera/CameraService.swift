import AVFoundation
import CoreVideo

/// Live camera capture. Frames are processed in memory only: never recorded, saved, or logged
/// (constitution Principle II). Late frames are dropped so tracking always sees the newest one.
final class CameraService: NSObject, @unchecked Sendable, AVCaptureVideoDataOutputSampleBufferDelegate {
    enum CameraError: Error {
        case noCamera
        case notAuthorized
        case cannotAddInput
        case cannotAddOutput
    }

    let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "cleanhands.camera", qos: .userInteractive)
    private let lock = NSLock()
    private var frameHandler: (@Sendable (CVPixelBuffer, Double) -> Void)?

    /// Called on the camera queue with each upright BGRA frame and its timestamp in seconds.
    func setFrameHandler(_ handler: (@Sendable (CVPixelBuffer, Double) -> Void)?) {
        lock.withLock { frameHandler = handler }
    }

    static var isAvailable: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
            || AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) != nil
    }

    static func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }

    func configure(setup: CameraSetup) throws {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: setup.position) else {
            throw CameraError.noCamera
        }
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.inputs.forEach(session.removeInput)
        session.outputs.forEach(session.removeOutput)
        session.sessionPreset = .hd1280x720

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw CameraError.cannotAddInput }
        session.addInput(input)

        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else { throw CameraError.cannotAddOutput }
        session.addOutput(output)

        if let connection = output.connection(with: .video) {
            // The interface is locked to portrait, so frames arrive upright and match the screen.
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = setup.mirrorsVideo
            }
        }

        try device.lockForConfiguration()
        device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
        device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
        device.unlockForConfiguration()
    }

    func start() {
        queue.async { [self] in
            if !session.isRunning { session.startRunning() }
        }
    }

    func stop() {
        queue.async { [self] in
            if session.isRunning { session.stopRunning() }
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        let handler = lock.withLock { frameHandler }
        handler?(pixelBuffer, time)
    }
}
