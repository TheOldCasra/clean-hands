import AVFAudio
import Foundation
import QuartzCore

/// Plays the pre-recorded Swahili narration clips (research R10) by clip ID (`N01`…`N21`).
@MainActor
final class NarrationPlayer: NSObject, AVAudioPlayerDelegate {
    static let allClips = (1...21).map { String(format: "N%02d", $0) }

    private var player: AVAudioPlayer?
    private var queue: [String] = []
    private var completion: ((Bool) -> Void)?
    private var allPlayed = true
    private var deferredUntil: CFTimeInterval = 0
    /// Bumped by `stop()` and each new `play`, so a stale deferred start never fires.
    private var generation = 0

    private(set) var lastClip: String?
    /// The clip playing now; nil when silent or waiting for a deferred start.
    private(set) var currentClip: String?
    /// `CACurrentMediaTime()` of `currentClip`'s actual start.
    private(set) var currentClipStartedAt: CFTimeInterval?
    /// True while a clip plays or a deferred clip waits to start.
    private(set) var isPlaying = false

    /// Called at each clip's actual start (session log `narrationPlayed`, prompt cues).
    var onClipPlayed: ((String) -> Void)?
    /// Called when a clip stops: `finished` is false if it was missing, failed, or was cut short.
    var onClipEnded: ((String, Bool) -> Void)?

    override init() {
        super.init()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    /// Clip IDs that are not in the app bundle. A session must not start unless this is empty
    /// (002 FR-004b).
    static func missingClips(in bundle: Bundle = .main) -> [String] {
        allClips.filter { bundle.url(forResource: $0, withExtension: "m4a") == nil }
    }

    /// What the bundled narration is, from `narration-manifest.json` (updated by
    /// `tools/narration.py`): how many clips are Swahili recordings, how many a synthetic Swahili
    /// voice, and how many lines a native speaker has reviewed.
    struct Status: Sendable, Equatable {
        var recorded = 0
        var synthetic = 0
        var reviewed = 0
        var total = 21
    }

    static func status(in bundle: Bundle = .main) -> Status {
        struct Manifest: Decodable {
            struct Clip: Decodable { let recording: String; let swStatus: String }
            let clips: [Clip]
        }
        guard let url = bundle.url(forResource: "narration-manifest", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let manifest = try? JSONDecoder().decode(Manifest.self, from: data) else { return Status() }
        return Status(
            recorded: manifest.clips.filter { $0.recording == "swahili" }.count,
            synthetic: manifest.clips.filter { $0.recording == "swahili-synthetic" }.count,
            reviewed: manifest.clips.filter { $0.swStatus == "reviewed" }.count,
            total: manifest.clips.count
        )
    }

    /// Plays clips one after another, replacing anything playing. `completion` receives true only
    /// if every clip played to its end.
    func play(_ clips: [String], completion: ((Bool) -> Void)? = nil) {
        stop()
        queue = clips
        self.completion = completion
        allPlayed = true
        isPlaying = !clips.isEmpty
        playNext()
    }

    func play(_ clip: String, completion: ((Bool) -> Void)? = nil) {
        play([clip], completion: completion)
    }

    func replay() {
        guard let lastClip else { return }
        play(lastClip)
    }

    /// Holds every clip start until `time` (`CACurrentMediaTime`), e.g. 0.8 s after the lamp click,
    /// so no clip begins over it (002 FR-016). A clip already playing is not affected.
    func deferStarts(until time: CFTimeInterval) {
        deferredUntil = max(deferredUntil, time)
    }

    func stop() {
        generation += 1
        if let currentClip, player?.isPlaying == true { onClipEnded?(currentClip, false) }
        player?.stop()
        player = nil
        queue = []
        completion = nil
        currentClip = nil
        currentClipStartedAt = nil
        isPlaying = false
    }

    private func playNext() {
        guard !queue.isEmpty else {
            finish()
            return
        }
        let wait = deferredUntil - CACurrentMediaTime()
        if wait > 0 {
            let token = generation
            DispatchQueue.main.asyncAfter(deadline: .now() + wait) { [weak self] in
                guard let self, self.generation == token else { return }
                self.playNext()
            }
            return
        }
        let clip = queue.removeFirst()
        lastClip = clip
        guard let url = Bundle.main.url(forResource: clip, withExtension: "m4a"),
              let player = try? AVAudioPlayer(contentsOf: url), player.play() else {
            // A missing clip must not stall the flow; hop so callers never re-enter synchronously.
            allPlayed = false
            onClipEnded?(clip, false)
            let token = generation
            DispatchQueue.main.async { [weak self] in
                guard let self, self.generation == token else { return }
                self.playNext()
            }
            return
        }
        self.player = player
        player.delegate = self
        currentClip = clip
        currentClipStartedAt = CACurrentMediaTime()
        onClipPlayed?(clip)
    }

    private func finish() {
        isPlaying = false
        currentClip = nil
        currentClipStartedAt = nil
        let done = completion
        let played = allPlayed
        completion = nil
        done?(played)
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        MainActor.assumeIsolated {
            guard player === self.player else { return }
            if let clip = currentClip { onClipEnded?(clip, flag) }
            if !flag { allPlayed = false }
            currentClip = nil
            currentClipStartedAt = nil
            playNext()
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        MainActor.assumeIsolated {
            guard player === self.player else { return }
            if let clip = currentClip { onClipEnded?(clip, false) }
            allPlayed = false
            currentClip = nil
            currentClipStartedAt = nil
            playNext()
        }
    }
}
