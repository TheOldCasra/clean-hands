import AVFAudio
import Foundation
import Testing
@testable import CleanHands

/// The bundled narration: every clip present, within its length limit, with its Swahili text
/// (research R10, tasks T096–T097; FR-004b needs every clip before a session starts).
@MainActor
struct NarrationManifestTests {
    private struct Manifest: Decodable {
        struct Clip: Decodable {
            let id: String
            let file: String
            let sw: String
            let swStatus: String
            let recording: String
            let maxSeconds: Double
        }
        let clips: [Clip]
    }

    private func manifest() throws -> Manifest {
        let url = try #require(Bundle.main.url(forResource: "narration-manifest", withExtension: "json"))
        return try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: url))
    }

    @Test func everyClipIsListedOnceInOrder() throws {
        #expect(try manifest().clips.map(\.id) == NarrationPlayer.allClips)
    }

    @Test func everyClipIsBundled() {
        #expect(NarrationPlayer.missingClips().isEmpty)
    }

    @Test func everyClipHasSwahiliText() throws {
        for clip in try manifest().clips {
            #expect(!clip.sw.isEmpty, "\(clip.id) has no Swahili text")
            #expect(["draft", "reviewed"].contains(clip.swStatus), "\(clip.id): \(clip.swStatus)")
        }
    }

    @Test func everyClipFitsItsLimit() throws {
        for clip in try manifest().clips {
            let url = try #require(Bundle.main.url(forResource: clip.id, withExtension: "m4a"))
            let seconds = try AVAudioPlayer(contentsOf: url).duration
            #expect(seconds > 0.3 && seconds <= clip.maxSeconds, "\(clip.id): \(seconds) s")
            #expect(clip.maxSeconds == (["N04", "N19"].contains(clip.id) ? 25 : 12))
        }
    }
}
