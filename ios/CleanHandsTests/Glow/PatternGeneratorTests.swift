import Testing
@testable import CleanHands

struct PatternGeneratorTests {
    @Test func sameSeedGivesIdenticalMarks() throws {
        let look = try bundledLook()
        #expect(PatternGenerator.generate(seed: 42, config: look) == PatternGenerator.generate(seed: 42, config: look))
        #expect(PatternGenerator.generate(seed: 42, config: look) != PatternGenerator.generate(seed: 43, config: look))
    }

    @Test func defaultCountsPerHandSide() throws {
        let look = try bundledLook()
        let pattern = PatternGenerator.generate(seed: 7, config: look)
        for hand in Handedness.allCases {
            for side in PatternSide.allCases {
                let marks = pattern.marks(hand: hand, side: side)
                #expect(marks.filter { $0.kind == .cap }.count == 5)
                #expect(marks.filter { $0.kind == .streak }.count == 24)
                #expect(marks.filter { $0.kind == .fleck }.count == 220)
                #expect(marks.filter { $0.kind == .patch }.count == 9)
            }
        }
    }

    @Test func exactlyOneCapPerFingerAndThumbPerSide() throws {
        let look = try bundledLook()
        let pattern = PatternGenerator.generate(seed: 11, config: look)
        for hand in Handedness.allCases {
            for side in PatternSide.allCases {
                let tips = pattern.marks(hand: hand, side: side).filter { $0.kind == .cap }.compactMap { mark -> Int? in
                    if case let .bone(_, b, _, _) = mark.anchor { return b }
                    return nil
                }
                #expect(tips.sorted() == [4, 8, 12, 16, 20])
            }
        }
    }

    @Test(arguments: [UInt64(1), 42, 0xC1EA4, 987_654_321])
    func leftAndRightCountsPerRegionDifferByAtMostTenPercent(seed: UInt64) throws {
        let look = try bundledLook()
        let pattern = PatternGenerator.generate(seed: seed, config: look)
        for side in PatternSide.allCases {
            for region in GlowRegion.allCases {
                let left = pattern.marks(hand: .left, side: side).filter { $0.region == region }.count
                let right = pattern.marks(hand: .right, side: side).filter { $0.region == region }.count
                #expect(Double(abs(left - right)) <= look.pattern.leftRightMaxDiff * Double(max(left, right)))
            }
        }
    }

    @Test func regionDistributionFollowsTheWeights() throws {
        let look = try bundledLook()
        let pattern = PatternGenerator.generate(seed: 5, config: look)
        let marks = pattern.marks(hand: .right, side: .palm).filter { $0.kind == .fleck }
        // Density (marks per area) relative to the palm centre should match the region weights.
        let palmDensity = Double(marks.filter { $0.region == .palm }.count) / PatternGenerator.area(.palm, side: .palm)
        for region in PatternGenerator.regions(for: .fleck, side: .palm) {
            let density = Double(marks.filter { $0.region == region }.count) / PatternGenerator.area(region, side: .palm)
            let expected = look.weight(for: region) / look.weight(for: .palm)
            #expect(abs(density / palmDensity - expected) <= expected * 0.15, "\(region)")
        }
    }

    @Test func palmAndBackPatternsDiffer() throws {
        let look = try bundledLook()
        let pattern = PatternGenerator.generate(seed: 3, config: look)
        let palm = pattern.marks(hand: .left, side: .palm).map(\.anchor)
        let back = pattern.marks(hand: .left, side: .back).map(\.anchor)
        #expect(palm != back)
        #expect(pattern.marks(hand: .left, side: .back).contains { $0.region == .backOfHand })
        #expect(!pattern.marks(hand: .left, side: .palm).contains { $0.region == .backOfHand })
    }

    @Test func boneAnchorsStayWithinLimits() throws {
        let look = try bundledLook()
        for mark in PatternGenerator.generate(seed: 21, config: look).marks {
            switch mark.anchor {
            case let .bone(_, _, t, s):
                #expect((0...1).contains(t))
                #expect((-0.7...0.7).contains(s))
            case let .triangle(_, _, _, u, v, w):
                #expect(abs(u + v + w - 1) < 1e-4)
                #expect(min(u, v, w) >= 0)
            }
        }
    }
}
