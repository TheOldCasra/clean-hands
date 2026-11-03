import Testing
@testable import CleanHands

/// Coverage on the reference pose, measured the way `tools/measure_glow.py` measures the owner's
/// reference images (research R7; docs/reference/README.md).
struct CoverageTests {
    /// ref-01, fifths of the hand from the fingertips down: 61%, 27%, 13%, 8%, 10%.
    static let referenceFifths: [Float] = [0.61, 0.27, 0.13, 0.08, 0.10]

    @Test(arguments: [UInt64(1), 42, 0xC1EA4, 987_654_321, AppModel.demoSeed])
    func palmMatchesTheReference(seed: UInt64) throws {
        let look = try bundledLook()
        let pattern = PatternGenerator.generate(seed: seed, config: look)
        for hand in Handedness.allCases {
            let result = CoverageEstimator.measure(pattern: pattern, hand: hand, side: .palm, config: look, step: 1.5)
            #expect(Double(result.coverage) >= look.glow.coverageTarget.min, "\(hand) coverage \(result.coverage)")
            #expect(Double(result.coverage) <= look.glow.coverageTarget.max, "\(hand) coverage \(result.coverage)")
            for (i, target) in Self.referenceFifths.enumerated() {
                #expect(abs(result.fifths[i] - target) <= 0.10, "\(hand) fifth \(i + 1): \(result.fifths[i])")
            }
        }
    }

    @Test(arguments: [UInt64(1), 42, 0xC1EA4])
    func backOfHandCoverageIsInRange(seed: UInt64) throws {
        let look = try bundledLook()
        let pattern = PatternGenerator.generate(seed: seed, config: look)
        for hand in Handedness.allCases {
            let result = CoverageEstimator.measure(pattern: pattern, hand: hand, side: .back, config: look, step: 1.5)
            #expect(Double(result.coverage) >= look.glow.coverageTarget.min)
            #expect(Double(result.coverage) <= look.glow.coverageTarget.max)
        }
    }

    @Test func palmCentreIsMostlyClean() throws {
        let look = try bundledLook()
        let pattern = PatternGenerator.generate(seed: 42, config: look)
        let result = CoverageEstimator.measure(pattern: pattern, hand: .right, side: .palm, config: look, step: 1.5)
        // Fingertips dominate: several times the glow of the lower palm.
        #expect(result.fifths[0] > 3 * result.fifths[3])
    }
}
