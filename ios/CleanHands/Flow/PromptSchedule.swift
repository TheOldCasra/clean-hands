/// When the lamp may switch on and when the reveal prompts appear (002 contracts/choreography.md
/// §5). A pure value: the app feeds it clip starts and ends, unpaused time, and gates, and reads
/// the result. Cues are latched here, not in view state, so pauses and missing clips cannot lose
/// them.
struct PromptSchedule: Sendable, Equatable {
    /// The lamp switches on only after uvIntro has lasted this long (choreography G3).
    static let introDwell: Double = 1.0
    /// Fallbacks from the lamp switch, in unpaused time (choreography §5).
    static let turnHandFallback: Double = 14
    static let viewButtonsFallback: Double = 26

    // MARK: Clock

    /// Seconds of unpaused session time; advances only while not paused.
    private(set) var now: Double = 0

    mutating func advance(by dt: Double, paused: Bool) {
        if !paused { now += max(dt, 0) }
    }

    // MARK: Spoken-explanation gate (FR-004b)

    private(set) var introEnteredAt: Double?
    private(set) var explanationFinished = false
    private(set) var explanationFailed = false
    private(set) var facilitatorContinued = false

    mutating func enterIntro() {
        introEnteredAt = now
        explanationFinished = false
        explanationFailed = false
        facilitatorContinued = false
    }

    /// N04 ended: `normally` is false if it was missing, failed, or cut short.
    mutating func explanationEnded(normally: Bool) {
        if normally { explanationFinished = true } else { explanationFailed = true }
    }

    /// The facilitator continues after explaining in person. Only counts if N04 failed.
    mutating func facilitatorNext() {
        if explanationFailed { facilitatorContinued = true }
    }

    /// The facilitator's Next is offered only when the explanation failed.
    var needsFacilitator: Bool { explanationFailed && !facilitatorContinued }

    /// Whether the lamp may switch on now. Never on a timer alone.
    var lampMayStart: Bool {
        guard let entered = introEnteredAt else { return false }
        if explanationFailed { return facilitatorContinued }
        return explanationFinished && now - entered >= Self.introDwell
    }

    /// Unpaused seconds until the dwell is over, if the explanation has finished; else nil.
    var secondsUntilLampMayStart: Double? {
        guard let entered = introEnteredAt, explanationFinished, !explanationFailed else { return nil }
        return max(0, entered + Self.introDwell - now)
    }

    // MARK: Reveal prompts

    enum Prompt: Sendable, Equatable { case turnHand, viewButtons }

    private(set) var lampSwitchedAt: Double?
    private(set) var spreadEnded = false
    private(set) var turnHandCued = false
    private(set) var viewButtonsCued = false
    /// Increments each time a hint should play its motion once (N06 for turn-hand, N01/N02 for the
    /// positioning arrow).
    private(set) var turnHandHints = 0
    private(set) var positioningNudges = 0
    /// True when the last change came from a resume, so it must appear without an entrance.
    private(set) var lastChangeWithoutEntrance = false

    /// First lamp switch-on of the session (t0). Later switches do not move t0.
    mutating func lampSwitched() {
        if lampSwitchedAt == nil { lampSwitchedAt = now }
    }

    mutating func markSpreadEnded() {
        spreadEnded = true
    }

    mutating func clipStarted(_ clip: String) {
        lastChangeWithoutEntrance = false
        switch clip {
        case "N01", "N02":
            positioningNudges += 1
        case "N06" where lampSwitchedAt != nil:
            turnHandCued = true
            turnHandHints += 1
        case "N07" where lampSwitchedAt != nil:
            viewButtonsCued = true
        default:
            break
        }
    }

    /// After a pause or face guard: the narration chain was stopped, so no clip will introduce
    /// the prompts that are still pending; they appear at once, without an entrance.
    mutating func resumed() {
        guard lampSwitchedAt != nil, !viewButtonsCued else { return }
        turnHandCued = true
        viewButtonsCued = true
        lastChangeWithoutEntrance = true
    }

    private var sinceSwitch: Double? { lampSwitchedAt.map { now - $0 } }

    /// The turn-hand prompt is shown from its cue (never before the spread ends, G2) until the
    /// eye/lamp buttons appear.
    var turnHandVisible: Bool {
        guard spreadEnded, !viewButtonsVisible, let since = sinceSwitch else { return false }
        return turnHandCued || since >= Self.turnHandFallback
    }

    var viewButtonsVisible: Bool {
        guard spreadEnded, let since = sinceSwitch else { return false }
        return viewButtonsCued || since >= Self.viewButtonsFallback
    }

    var visiblePrompts: [Prompt] {
        (turnHandVisible ? [.turnHand] : []) + (viewButtonsVisible ? [.viewButtons] : [])
    }

    /// Back to the start for a new session.
    mutating func reset() {
        self = PromptSchedule()
    }
}
