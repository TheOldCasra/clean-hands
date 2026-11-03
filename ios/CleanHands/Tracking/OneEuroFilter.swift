import Foundation
import simd

/// One Euro filter (Casiez et al., 2012) on a 2D point: damps jitter when the hand is still and
/// stays responsive when it moves (research R8).
struct OneEuroFilter: Sendable {
    var minCutoff: Float = 1.0
    var beta: Float = 0.007
    var derivativeCutoff: Float = 1.0

    private var previous: SIMD2<Float>?
    private var previousDerivative = SIMD2<Float>.zero
    private var previousTime: Double?

    init(minCutoff: Float = 1.0, beta: Float = 0.007, derivativeCutoff: Float = 1.0) {
        self.minCutoff = minCutoff
        self.beta = beta
        self.derivativeCutoff = derivativeCutoff
    }

    mutating func reset() {
        previous = nil
        previousTime = nil
        previousDerivative = .zero
    }

    mutating func filter(_ value: SIMD2<Float>, at time: Double) -> SIMD2<Float> {
        guard let previous, let previousTime, time > previousTime else {
            self.previous = value
            self.previousTime = time
            return value
        }
        let dt = Float(time - previousTime)
        let derivative = (value - previous) / dt
        let smoothedDerivative = mix(previousDerivative, derivative, t: Self.alpha(cutoff: derivativeCutoff, dt: dt))
        let cutoff = minCutoff + beta * simd_length(smoothedDerivative)
        let result = mix(previous, value, t: Self.alpha(cutoff: cutoff, dt: dt))
        self.previous = result
        self.previousDerivative = smoothedDerivative
        self.previousTime = time
        return result
    }

    private static func alpha(cutoff: Float, dt: Float) -> Float {
        let tau = 1 / (2 * Float.pi * cutoff)
        return 1 / (1 + tau / dt)
    }
}
