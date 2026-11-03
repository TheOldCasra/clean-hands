import AVFAudio
import Foundation

/// Plays the pre-recorded Swahili narration clips (research R10) by clip ID (`N01`…`N21`).
@MainActor
final class NarrationPlayer: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    private var queue: [String] = []
    private var completion: (() -> Void)?
    private(set) var lastClip: String?
    private(set) var isPlaying = false

    /// Called each time a clip starts, for the session log (`narrationPlayed`).
    var onClipPlayed: ((String) -> Void)?

    override init() {
        super.init()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    /// Plays clips one after another, replacing anything playing, then calls `completion`.
    func play(_ clips: [String], completion: (() -> Void)? = nil) {
        stop()
        queue = clips
        self.completion = completion
        playNext()
    }

    func play(_ clip: String, completion: (() -> Void)? = nil) {
        play([clip], completion: completion)
    }

    func replay() {
        guard let lastClip else { return }
        play(lastClip)
    }

    func stop() {
        player?.stop()
        player = nil
        queue = []
        completion = nil
        isPlaying = false
    }

    private func playNext() {
        guard !queue.isEmpty else {
            isPlaying = false
            let done = completion
            completion = nil
            done?()
            return
        }
        let clip = queue.removeFirst()
        lastClip = clip
        onClipPlayed?(clip)
        guard let url = Bundle.main.url(forResource: clip, withExtension: "m4a"),
              let player = try? AVAudioPlayer(contentsOf: url) else {
            // A missing clip must not stall the flow.
            DispatchQueue.main.async { [weak self] in self?.playNext() }
            return
        }
        self.player = player
        player.delegate = self
        isPlaying = true
        player.play()
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        MainActor.assumeIsolated {
            guard player === self.player else { return }
            playNext()
        }
    }
}
