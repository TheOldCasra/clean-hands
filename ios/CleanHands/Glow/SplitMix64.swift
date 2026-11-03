/// SplitMix64 (Vigna). Our own generator, not the system RNG, so the same seed gives the same
/// pattern on every iPadOS version (FR-006).
struct SplitMix64: RandomNumberGenerator, Sendable {
    private(set) var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform in [0, 1), from the top 24 bits so it is exact in Float.
    mutating func unit() -> Float {
        Float(next() >> 40) / Float(1 << 24)
    }

    mutating func uniform(_ range: ClosedRange<Float>) -> Float {
        range.lowerBound + unit() * (range.upperBound - range.lowerBound)
    }

    mutating func index(_ count: Int) -> Int {
        Int(next() % UInt64(count))
    }
}
