import Testing
@testable import CleanHands

struct FadeStateTests {
    @Test func newStateStartsAtFullGlow() {
        let fade = FadeState()
        for hand in Handedness.allCases {
            for side in PatternSide.allCases {
                for region in GlowRegion.allCases {
                    #expect(fade.multiplier(hand: hand, side: side, region: region) == 1)
                }
            }
        }
    }

    @Test func handFadesInOverThreeHundredMilliseconds() {
        var fade = FadeState(fadeInMs: 300, fadeOutMs: 250)
        fade.updatePresence(present: [1], dt: 0.15)
        #expect(abs(fade.presence(of: 1) - 0.5) < 1e-4)
        fade.updatePresence(present: [1], dt: 0.15)
        #expect(fade.presence(of: 1) == 1)
    }

    @Test func handFadesOutOverTwoHundredFiftyMillisecondsAndIsForgotten() {
        var fade = FadeState(fadeInMs: 300, fadeOutMs: 250)
        fade.updatePresence(present: [1], dt: 1)
        fade.updatePresence(present: [], dt: 0.125)
        #expect(abs(fade.presence(of: 1) - 0.5) < 1e-4)
        fade.updatePresence(present: [], dt: 0.2)
        #expect(fade.presence(of: 1) == 0)
        #expect(!fade.anyVisible)
    }

    @Test func multipliersAreClampedAndPerRegion() {
        var fade = FadeState()
        fade.setMultiplier(-1, hand: .left, side: .palm, region: .palm)
        fade.setMultiplier(0.3, region: .thumb)
        #expect(fade.multiplier(hand: .left, side: .palm, region: .palm) == 0)
        #expect(fade.multiplier(hand: .right, side: .palm, region: .palm) == 1)
        #expect(fade.multiplier(hand: .right, side: .back, region: .thumb) == Float(0.3))
    }
}
