import Testing
@testable import CleanHands

struct SplitMix64Tests {
    @Test func matchesReferenceOutputForSeedZero() {
        var rng = SplitMix64(seed: 0)
        #expect(rng.next() == 0xE220_A839_7B1D_CDAF)
        #expect(rng.next() == 0x6E78_9E6A_A1B9_65F4)
        #expect(rng.next() == 0x06C4_5D18_8009_454F)
    }

    @Test func matchesReferenceOutputForSeed1234567() {
        var rng = SplitMix64(seed: 1_234_567)
        let expected: [UInt64] = [6_457_827_717_110_365_317, 3_203_168_211_198_807_973, 9_817_491_932_198_370_423,
                                  4_593_380_528_125_082_431, 16_408_922_859_458_223_821]
        #expect((0..<5).map { _ in rng.next() } == expected)
    }

    @Test func unitStaysInRange() {
        var rng = SplitMix64(seed: 99)
        for _ in 0..<10_000 {
            let u = rng.unit()
            #expect(u >= 0 && u < 1)
        }
    }
}
