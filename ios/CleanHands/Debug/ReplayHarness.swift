#if DEBUG || QA_TOOLS
import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

/// Runs the full tracking and rendering pipeline on a test video and writes metrics for gates 1–2
/// (research R14): time to first detection, per-frame detection rate, tracking rate, plus one
/// rendered overlay per second for the 20-pose spill check. Test videos are recorded outside the
/// app, with the Camera app, from consenting volunteers who are not study participants.
struct ReplayReport: Codable {
    var video: String
    var device: String
    var frames: Int
    var durationSeconds: Double
    var framesWithHand: Int
    var detectionRate: Double
    var timeToFirstHandSeconds: Double?
    var meanTrackingMs: Double
    var trackingHz: Double
    var overlays: Int
}

@MainActor
final class ReplayHarness {
    let renderer: Renderer
    let pattern: GlowPattern
    var overlayInterval: Double = 1

    init(renderer: Renderer, pattern: GlowPattern) {
        self.renderer = renderer
        self.pattern = pattern
    }

    func run(url: URL, setup: CameraSetup, progress: @escaping (Double) -> Void) async throws -> (ReplayReport, URL) {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw CocoaError(.fileReadCorruptFile) }
        let duration = try await asset.load(.duration).seconds
        let composition = try await AVMutableVideoComposition.videoComposition(withPropertiesOf: asset)
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderVideoCompositionOutput(videoTracks: [track], videoSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferMetalCompatibilityKey as String: true,
        ])
        output.videoComposition = composition
        reader.add(output)
        reader.startReading()

        let name = url.deletingPathExtension().lastPathComponent
        let folder = URL.documentsDirectory.appending(path: "replay/\(name)-\(Int(Date().timeIntervalSince1970))")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let pipeline = TrackingPipeline(tracker: VisionHandTracker(), setup: setup)
        let previousPattern = renderer.pattern
        renderer.pattern = pattern
        defer { renderer.pattern = previousPattern }

        var frames = 0, withHand = 0, overlays = 0
        var firstHand: Double?
        var trackingTotal: Double = 0
        var nextOverlay: Double = 0
        while let sample = output.copyNextSampleBuffer() {
            guard let buffer = CMSampleBufferGetImageBuffer(sample) else { continue }
            let time = CMSampleBufferGetPresentationTimeStamp(sample).seconds
            let result = pipeline.process(buffer, at: time)
            frames += 1
            trackingTotal += result.trackingSeconds
            if !result.frame.hands.isEmpty {
                withHand += 1
                if firstHand == nil { firstHand = time }
            }
            if time >= nextOverlay {
                nextOverlay = time + overlayInterval
                if let image = renderer.renderOffscreen(pixelBuffer: buffer, frame: result.frame, uvAmount: 1),
                   let data = UIImage(cgImage: image).pngData() {
                    try data.write(to: folder.appending(path: String(format: "t%06.2f.png", time)))
                    overlays += 1
                }
            }
            if frames % 10 == 0 {
                progress(duration > 0 ? time / duration : 0)
                await Task.yield()
            }
        }

        let meanTracking = frames > 0 ? trackingTotal / Double(frames) : 0
        let report = ReplayReport(
            video: url.lastPathComponent,
            device: UIDevice.current.model + " " + UIDevice.current.systemVersion,
            frames: frames,
            durationSeconds: duration,
            framesWithHand: withHand,
            detectionRate: frames > 0 ? Double(withHand) / Double(frames) : 0,
            timeToFirstHandSeconds: firstHand,
            meanTrackingMs: meanTracking * 1000,
            trackingHz: meanTracking > 0 ? 1 / meanTracking : 0,
            overlays: overlays
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(report).write(to: folder.appending(path: "report.json"))
        return (report, folder)
    }
}

struct ReplayHarnessView: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var importing = false
    @State private var running = false
    @State private var progress: Double = 0
    @State private var report: ReplayReport?
    @State private var folder: URL?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button { importing = true } label: { Text(verbatim: "Choose test video…") }
                        .disabled(running)
                    if running { ProgressView(value: progress) }
                }
                if let report {
                    Section {
                        row("Frames", "\(report.frames)")
                        row("Detection rate", String(format: "%.1f%%", report.detectionRate * 100))
                        row("First hand at", report.timeToFirstHandSeconds.map { String(format: "%.2f s", $0) } ?? "never")
                        row("Tracking", String(format: "%.1f ms (%.0f Hz)", report.meanTrackingMs, report.trackingHz))
                        row("Overlays", "\(report.overlays)")
                        if let folder { row("Saved to", "Files › Clean Hands › \(folder.lastPathComponent)") }
                    } header: { Text(verbatim: "Report") }
                }
                if let error {
                    Text(verbatim: error).foregroundStyle(.red)
                }
            }
            .navigationTitle(Text(verbatim: "Replay harness"))
            .toolbar { Button { dismiss() } label: { Text(verbatim: "Done") } }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.movie]) { result in
                guard case let .success(url) = result else { return }
                run(url)
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        LabeledContent { Text(verbatim: value) } label: { Text(verbatim: label) }
    }

    private func run(_ url: URL) {
        running = true
        error = nil
        Task {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let harness = ReplayHarness(renderer: model.renderer,
                                        pattern: PatternGenerator.generate(seed: AppModel.demoSeed, config: model.look))
            do {
                let (report, folder) = try await harness.run(url: url, setup: model.cameraSetup) { progress = $0 }
                self.report = report
                self.folder = folder
            } catch {
                self.error = error.localizedDescription
            }
            running = false
        }
    }
}
#endif
