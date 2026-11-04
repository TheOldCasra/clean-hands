// Per-frame mean brightness of a screen recording, for 002 SC-001 (lamp-transition L7).
// Prints the largest consecutive-frame step in mean luma (0–255) and exits non-zero above 25.
//
// Usage: swift tools/measure_transition.swift recording.mov [--all]
// Recordings follow docs/qa/recording-protocol.md (consenting volunteers only).
import AVFoundation
import Foundation

let arguments = CommandLine.arguments.dropFirst()
guard let path = arguments.first(where: { !$0.hasPrefix("--") }) else {
    print("usage: swift tools/measure_transition.swift recording.mov [--all]")
    exit(2)
}
let printAll = arguments.contains("--all")
let limit = 25.0

let asset = AVURLAsset(url: URL(fileURLWithPath: path))
let semaphore = DispatchSemaphore(value: 0)
var lumas: [(time: Double, luma: Double)] = []

Task {
    defer { semaphore.signal() }
    do {
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            print("no video track"); exit(2)
        }
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ])
        reader.add(output)
        reader.startReading()
        while let sample = output.copyNextSampleBuffer() {
            guard let buffer = CMSampleBufferGetImageBuffer(sample) else { continue }
            CVPixelBufferLockBaseAddress(buffer, .readOnly)
            let base = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: UInt8.self)
            let width = CVPixelBufferGetWidth(buffer), height = CVPixelBufferGetHeight(buffer)
            let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
            var sum = 0.0, count = 0.0
            // Every 4th pixel in each direction is plenty for a mean.
            for y in stride(from: 0, to: height, by: 4) {
                for x in stride(from: 0, to: width, by: 4) {
                    let o = y * rowBytes + x * 4
                    sum += 0.114 * Double(base[o]) + 0.587 * Double(base[o + 1]) + 0.299 * Double(base[o + 2])
                    count += 1
                }
            }
            CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
            lumas.append((CMSampleBufferGetPresentationTimeStamp(sample).seconds, sum / count))
        }
    } catch {
        print("error: \(error)"); exit(2)
    }
}
semaphore.wait()

guard lumas.count > 1 else { print("fewer than two frames"); exit(2) }
var worst = (step: 0.0, time: 0.0)
for i in 1..<lumas.count {
    let step = abs(lumas[i].luma - lumas[i - 1].luma)
    if printAll { print(String(format: "%8.3f s  %6.1f  Δ %5.1f", lumas[i].time, lumas[i].luma, step)) }
    if step > worst.step { worst = (step, lumas[i].time) }
}
print(String(format: "frames %d, largest step %.1f / 255 at %.3f s (limit %.0f)", lumas.count, worst.step, worst.time, limit))
exit(worst.step > limit ? 1 : 0)
