import Testing
@testable import CleanHands

struct LookConfigTests {
    @Test func bundledLookDecodes() throws {
        let look = try bundledLook()
        #expect(look.version == 1)
        #expect(look.uvView.skinRamp.count == 4)
    }

    @Test func rehearsalTotalsAtLeastTwentySeconds() throws {
        let look = try bundledLook()
        #expect(look.rehearsal.stepSeconds.count == 6)
        #expect(look.rehearsal.stepSeconds.reduce(0, +) >= 20)
    }

    @Test func coverageTargetMatchesSpec() throws {
        let look = try bundledLook()
        #expect(look.glow.coverageTarget.min == 0.15)
        #expect(look.glow.coverageTarget.max == 0.25)
    }

    @Test func roundTrips() throws {
        let look = try bundledLook()
        #expect(try LookConfig.decode(look.encoded()) == look)
    }
}
