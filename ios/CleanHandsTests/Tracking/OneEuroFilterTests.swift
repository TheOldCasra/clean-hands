import Testing
import simd
@testable import CleanHands

struct OneEuroFilterTests {
    @Test func dampsJitterOnAStillHand() {
        var filter = OneEuroFilter()
        var rng = SplitMix64(seed: 7)
        var rawSpread: Float = 0
        var filteredSpread: Float = 0
        for i in 0..<300 {
            let noise = SIMD2(rng.uniform(-3...3), rng.uniform(-3...3))
            let out = filter.filter(SIMD2(100, 100) + noise, at: Double(i) / 30)
            if i > 30 {
                rawSpread += simd_length(noise)
                filteredSpread += simd_distance(out, SIMD2(100, 100))
            }
        }
        #expect(filteredSpread < rawSpread * 0.5)
    }

    @Test func followsAMoveWithBoundedLag() {
        var filter = OneEuroFilter()
        for i in 0..<30 { _ = filter.filter(SIMD2(0, 0), at: Double(i) / 30) }
        var out = SIMD2<Float>.zero
        // The hand jumps 300 px and stays; within a quarter second the output must have caught up.
        for i in 30..<38 { out = filter.filter(SIMD2(300, 0), at: Double(i) / 30) }
        #expect(out.x > 270)
    }

    @Test func firstSampleIsPassedThrough() {
        var filter = OneEuroFilter()
        #expect(filter.filter(SIMD2(5, 6), at: 1) == SIMD2(5, 6))
    }
}
