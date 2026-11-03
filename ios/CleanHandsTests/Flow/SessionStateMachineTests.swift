import Testing
@testable import CleanHands

struct SessionStateMachineTests {
    private func machine(at path: [SessionState]) throws -> SessionStateMachine {
        var m = SessionStateMachine()
        for state in path { try m.transition(to: state) }
        return m
    }

    private let toReveal: [SessionState] = [.consentCheck, .deviceReady, .positioning, .normalView, .uvIntro, .uvReveal]

    @Test func walksTheFullFlow() throws {
        var m = try machine(at: toReveal)
        try m.transition(to: .normalView2)
        try m.transition(to: .uvReveal)
        try m.transition(to: .quickRinseDemo)
        for step in 1...6 { try m.transition(to: .rehearsal(step)) }
        try m.transition(to: .realWashPrompt)
        try m.transition(to: .debrief)
        try m.transition(to: .ended(.completed))
        #expect(m.state == .ended(.completed))
    }

    @Test func rejectsIllegalTransitions() throws {
        var m = SessionStateMachine()
        #expect(throws: SessionStateMachine.TransitionError.self) { try m.transition(to: .uvReveal) }
        m = try machine(at: [.consentCheck, .blocked])
        #expect(throws: SessionStateMachine.TransitionError.self) { try m.transition(to: .deviceReady) }
        m = try machine(at: toReveal + [.quickRinseDemo, .rehearsal(1)])
        #expect(throws: SessionStateMachine.TransitionError.self) { try m.transition(to: .rehearsal(3)) }
        #expect(throws: SessionStateMachine.TransitionError.self) { try m.transition(to: .debrief) }
    }

    @Test func consentNotRecordedBlocksTheCamera() throws {
        let m = try machine(at: [.consentCheck, .blocked])
        #expect(!m.state.usesCamera)
    }

    @Test(arguments: [
        [SessionState.consentCheck],
        [.consentCheck, .deviceReady, .positioning],
        [.consentCheck, .deviceReady, .positioning, .normalView, .uvIntro, .uvReveal, .normalView2],
        [.consentCheck, .deviceReady, .positioning, .normalView, .uvIntro, .uvReveal, .quickRinseDemo, .rehearsal(1), .rehearsal(2)],
    ])
    func stopWorksFromEveryState(path: [SessionState]) throws {
        var m = try machine(at: path)
        m.stop(reason: .participantStopped)
        #expect(m.state == .ended(.aborted(.participantStopped)))
    }

    @Test func stopFromIdleAndAfterEnd() {
        var m = SessionStateMachine()
        m.stop(reason: .facilitatorStopped)
        #expect(m.state == .ended(.aborted(.facilitatorStopped)))
        m.stop(reason: .participantStopped)
        #expect(m.state == .ended(.aborted(.facilitatorStopped)))
    }

    @Test func faceGuardPauseReturnsToThePreviousState() throws {
        var m = try machine(at: toReveal)
        m.pause(.faceGuard)
        #expect(m.state == .paused(.faceGuard))
        m.resume()
        #expect(m.state == .uvReveal)
    }

    @Test func pauseOnlyAppliesToCameraStates() throws {
        var m = try machine(at: [.consentCheck])
        m.pause(.faceGuard)
        #expect(m.state == .consentCheck)
    }

    @Test func rehearsalStepPauseResumesTheSameStep() throws {
        var m = try machine(at: toReveal + [.quickRinseDemo, .rehearsal(1), .rehearsal(2)])
        try m.transition(to: .paused(.step(2)))
        #expect(throws: SessionStateMachine.TransitionError.self) { try m.transition(to: .rehearsal(3)) }
        try m.transition(to: .rehearsal(2))
        #expect(m.state == .rehearsal(2))
    }

    @Test func remembersThatTheRevealStarted() throws {
        var m = try machine(at: [.consentCheck, .deviceReady, .positioning])
        #expect(!m.reachedReveal)
        try m.transition(to: .normalView)
        try m.transition(to: .uvIntro)
        #expect(m.reachedReveal)
        m.stop(reason: .participantStopped)
        #expect(m.reachedReveal)
        m.reset()
        #expect(!m.reachedReveal)
    }

    @Test func reportsEveryTransition() throws {
        var m = SessionStateMachine()
        var seen: [SessionState] = []
        m.onTransition = { _, to in seen.append(to) }
        try m.transition(to: .consentCheck)
        try m.transition(to: .deviceReady)
        m.stop(reason: .other)
        #expect(seen == [.consentCheck, .deviceReady, .ended(.aborted(.other))])
    }
}
