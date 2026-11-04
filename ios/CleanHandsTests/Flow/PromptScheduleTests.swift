import Testing
@testable import CleanHands

struct PromptScheduleTests {
    private func revealStarted() -> PromptSchedule {
        var s = PromptSchedule()
        s.enterIntro()
        s.explanationEnded(normally: true)
        s.advance(by: 1.0, paused: false)
        s.lampSwitched()
        return s
    }

    // MARK: Spoken-explanation gate (FR-004b)

    @Test func lampWaitsForTheExplanationAndTheDwell() {
        var s = PromptSchedule()
        s.enterIntro()
        s.advance(by: 30, paused: false)
        #expect(!s.lampMayStart, "never on a timer alone")
        s.explanationEnded(normally: true)
        #expect(s.lampMayStart)
    }

    @Test func shortExplanationStillHoldsTheDwell() {
        var s = PromptSchedule()
        s.enterIntro()
        s.advance(by: 0.4, paused: false)
        s.explanationEnded(normally: true)
        #expect(!s.lampMayStart)
        #expect(abs((s.secondsUntilLampMayStart ?? -1) - 0.6) < 1e-9)
        s.advance(by: 0.6, paused: false)
        #expect(s.lampMayStart)
    }

    @Test func failedExplanationWaitsForTheFacilitator() {
        var s = PromptSchedule()
        s.enterIntro()
        s.advance(by: 5, paused: false)
        s.explanationEnded(normally: false)
        #expect(!s.lampMayStart)
        #expect(s.needsFacilitator)
        s.advance(by: 60, paused: false)
        #expect(!s.lampMayStart)
        s.facilitatorNext()
        #expect(s.lampMayStart)
        #expect(!s.needsFacilitator)
    }

    @Test func facilitatorNextIsIgnoredWhileTheExplanationPlays() {
        var s = PromptSchedule()
        s.enterIntro()
        s.facilitatorNext()
        s.advance(by: 5, paused: false)
        #expect(!s.lampMayStart)
    }

    @Test func reenteringTheIntroStartsOver() {
        var s = PromptSchedule()
        s.enterIntro()
        s.explanationEnded(normally: true)
        s.advance(by: 2, paused: false)
        s.enterIntro()
        #expect(!s.lampMayStart)
    }

    // MARK: Reveal prompts (choreography §5)

    @Test func turnHandWaitsForItsCueAndTheSpread() {
        var s = revealStarted()
        s.clipStarted("N06")
        #expect(!s.turnHandVisible, "not before the spread ends (G2)")
        s.markSpreadEnded()
        #expect(s.turnHandVisible)
        #expect(!s.viewButtonsVisible)
        s.clipStarted("N07")
        #expect(s.viewButtonsVisible)
        #expect(!s.turnHandVisible, "turn-hand leaves when the eye/lamp buttons arrive")
    }

    @Test func fallbacksUseUnpausedTime() {
        var s = revealStarted()
        s.markSpreadEnded()
        s.advance(by: 13.9, paused: false)
        #expect(!s.turnHandVisible)
        s.advance(by: 100, paused: true)
        #expect(!s.turnHandVisible, "paused time does not count")
        s.advance(by: 0.2, paused: false)
        #expect(s.turnHandVisible)
        s.advance(by: 12, paused: false)
        #expect(s.viewButtonsVisible)
    }

    @Test func aCueLatchedBeforeAPauseSurvivesIt() {
        var s = revealStarted()
        s.markSpreadEnded()
        s.clipStarted("N06")
        s.advance(by: 30, paused: true)
        #expect(s.turnHandVisible)
    }

    @Test func resumeShowsPendingPromptsWithoutEntrance() {
        var s = revealStarted()
        s.markSpreadEnded()
        s.resumed()
        #expect(s.viewButtonsVisible)
        #expect(s.lastChangeWithoutEntrance)
    }

    @Test func aRepeatedCueReplaysOnlyTheHint() {
        var s = revealStarted()
        s.markSpreadEnded()
        s.clipStarted("N06")
        let hints = s.turnHandHints
        s.clipStarted("N06")
        #expect(s.turnHandHints == hints + 1)
        #expect(s.turnHandVisible)
    }

    @Test func cuesBeforeTheLampDoNotCount() {
        var s = PromptSchedule()
        s.clipStarted("N06")
        s.clipStarted("N07")
        s.lampSwitched()
        s.markSpreadEnded()
        #expect(!s.viewButtonsVisible)
    }

    @Test func positioningNudgesFollowN01AndN02() {
        var s = PromptSchedule()
        s.clipStarted("N01")
        s.clipStarted("N02")
        s.clipStarted("N03")
        #expect(s.positioningNudges == 2)
    }
}
