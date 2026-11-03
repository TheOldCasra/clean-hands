import CoreVideo
import simd

/// Even exposure for every skin tone (research R6): under real UV light all skin looks dark violet,
/// so the gain is set to land the mapped skin near the reference value whatever the skin tone.
enum Exposure {
    /// Mean brightness (0…1) of the hands, sampled along finger bones and inside the palm.
    /// Runs on the tracking queue; reads the frame in memory only.
    static func meanLuma(of pixelBuffer: CVPixelBuffer, hands: [TrackedHand]) -> Float? {
        guard !hands.isEmpty, CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_32BGRA else { return nil }
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let rowBytes = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let pixels = base.assumingMemoryBound(to: UInt8.self)

        func luma(at p: SIMD2<Float>) -> Float? {
            let x = Int(p.x), y = Int(p.y)
            guard x >= 1, y >= 1, x < width - 1, y < height - 1 else { return nil }
            var sum: Float = 0
            for dy in -1...1 {
                for dx in -1...1 {
                    let o = (y + dy) * rowBytes + (x + dx) * 4
                    sum += 0.114 * Float(pixels[o]) + 0.587 * Float(pixels[o + 1]) + 0.299 * Float(pixels[o + 2])
                }
            }
            return sum / (9 * 255)
        }

        var samples: [Float] = []
        for hand in hands {
            let j = hand.joints.map(\.position)
            for (a, b) in Anchoring.bones where b != Joint.forearm {
                if let l = luma(at: (j[a] + j[b]) / 2) { samples.append(l) }
            }
            for (a, b, c) in Anchoring.palmTriangles {
                if let l = luma(at: (j[a] + j[b] + j[c]) / 3) { samples.append(l) }
            }
        }
        guard !samples.isEmpty else { return nil }
        // Median, so rings and bright spots do not drag the gain.
        return samples.sorted()[samples.count / 2]
    }

    /// The ramp position whose colour has the target brightness (HSV value).
    static func targetRampPosition(ramp: [SIMD3<Float>], targetValue: Float) -> Float {
        var lo: Float = 0, hi: Float = 1
        for _ in 0..<24 {
            let mid = (lo + hi) / 2
            if rampColor(ramp, mid).max() < targetValue { lo = mid } else { hi = mid }
        }
        return (lo + hi) / 2
    }

    static func rampColor(_ ramp: [SIMD3<Float>], _ t: Float) -> SIMD3<Float> {
        let x = min(max(t, 0), 1) * Float(ramp.count - 1)
        let i = min(Int(x), ramp.count - 2)
        return simd_mix(ramp[i], ramp[i + 1], SIMD3(repeating: x - Float(i)))
    }
}
