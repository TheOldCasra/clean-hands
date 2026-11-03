/// Why a session ended early (data-model.md, `Session.abortReason`).
enum AbortReason: String, Codable, Sendable {
    case participantStopped, facilitatorStopped, faceGuard, deviceIssue, other
}

enum SessionOutcome: Equatable, Hashable, Sendable {
    case completed
    case aborted(AbortReason)
}

enum PauseReason: Equatable, Hashable, Sendable {
    case faceGuard
    case facilitator
    /// Rehearsal step n paused because a hand left the view.
    case step(Int)
}

/// The session flow (data-model.md, "State transitions").
enum SessionState: Equatable, Hashable, Sendable {
    case idle
    case consentCheck
    case blocked
    case deviceReady
    case positioning
    case normalView
    case uvIntro
    case uvReveal
    case normalView2
    case quickRinseDemo
    case rehearsal(Int)
    case realWashPrompt
    case debrief
    case paused(PauseReason)
    case ended(SessionOutcome)

    /// States in which the camera runs and the participant sees her hands.
    var usesCamera: Bool {
        switch self {
        case .positioning, .normalView, .uvIntro, .uvReveal, .normalView2, .quickRinseDemo, .rehearsal, .realWashPrompt:
            true
        default:
            false
        }
    }

    var isEnded: Bool {
        if case .ended = self { return true }
        return false
    }
}

/// Holds the current state and allows only the transitions in the data model. Every change is
/// reported to `onTransition`, which writes the session log (US2).
struct SessionStateMachine {
    enum TransitionError: Error, Equatable {
        case notAllowed(from: SessionState, to: SessionState)
    }

    private(set) var state: SessionState = .idle
    /// The state a pause returns to.
    private(set) var resumeState: SessionState?
    /// Whether the reveal has started, so an abort still gets the debrief (FR-021).
    private(set) var reachedReveal = false

    var onTransition: ((SessionState, SessionState) -> Void)?

    static func isAllowed(from: SessionState, to: SessionState) -> Bool {
        switch (from, to) {
        case (.idle, .consentCheck),
             (.consentCheck, .blocked), (.consentCheck, .deviceReady),
             (.blocked, .consentCheck),
             (.deviceReady, .positioning),
             (.positioning, .normalView),
             (.normalView, .uvIntro), (.normalView, .positioning),
             (.uvIntro, .uvReveal), (.uvIntro, .normalView),
             (.uvReveal, .normalView2), (.normalView2, .uvReveal),
             (.uvReveal, .quickRinseDemo), (.uvReveal, .debrief),
             (.quickRinseDemo, .rehearsal(1)),
             (.rehearsal(6), .realWashPrompt),
             (.realWashPrompt, .debrief),
             (.debrief, .ended(.completed)):
            return true
        case let (.rehearsal(n), .rehearsal(m)):
            return m == n + 1 && m <= 6
        case let (.rehearsal(n), .paused(.step(m))), let (.paused(.step(m)), .rehearsal(n)):
            return n == m
        case (_, .ended(.aborted)):
            return !from.isEnded
        case (.idle, .deviceReady):
            #if DEBUG || QA_TOOLS
            return true // Demo launcher only (tasks T047); never in the study build.
            #else
            return false
            #endif
        default:
            return false
        }
    }

    mutating func transition(to next: SessionState) throws {
        guard Self.isAllowed(from: state, to: next) else {
            throw TransitionError.notAllowed(from: state, to: next)
        }
        set(next)
    }

    /// Ends the session as aborted, from any state (Principle V: stop at any time, no penalty).
    mutating func stop(reason: AbortReason) {
        guard !state.isEnded else { return }
        resumeState = nil
        set(.ended(.aborted(reason)))
    }

    /// Pauses a camera state (face guard or facilitator); `resume()` returns to it.
    mutating func pause(_ reason: PauseReason) {
        guard state.usesCamera else { return }
        resumeState = state
        set(.paused(reason))
    }

    mutating func resume() {
        guard case .paused = state, let resumeState else { return }
        self.resumeState = nil
        set(resumeState)
    }

    /// Back to idle for the next session.
    mutating func reset() {
        resumeState = nil
        reachedReveal = false
        set(.idle)
    }

    private mutating func set(_ next: SessionState) {
        let previous = state
        state = next
        if next == .uvIntro { reachedReveal = true }
        if next == .idle { reachedReveal = false }
        onTransition?(previous, next)
    }
}
