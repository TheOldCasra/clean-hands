import Foundation
import simd

/// Every visual parameter of the UV look, mirroring `look.json` (contracts/look-config.md).
/// Distances are fractions of the hand's scale (wrist to middle-finger knuckle).
struct LookConfig: Codable, Equatable, Sendable {
    var version: Int
    var uvView: UVView
    var glow: Glow
    var pattern: Pattern
    var fade: Fade
    var rehearsal: Rehearsal
    var quality: Quality

    struct UVView: Codable, Equatable, Sendable {
        var background: String
        var skinRamp: [String]
        var skinTargetValue: Double
        var skinLocalContrast: Double
        var lightPool: LightPool
        var nailTint: NailTint
    }

    struct LightPool: Codable, Equatable, Sendable {
        var dilate: Double
        var blur: Double
        var falloff: Double
    }

    struct NailTint: Codable, Equatable, Sendable {
        var color: String
        var strength: Double
    }

    struct Glow: Codable, Equatable, Sendable {
        var palette: Palette
        var hueJitter: Double
        var grain: Grain
        var skinDetailStrength: Double
        var bloom: Bloom
        var coverageTarget: Range
    }

    struct Palette: Codable, Equatable, Sendable {
        var low: String
        var mid: String
        var high: String
        var peak: String
    }

    struct Grain: Codable, Equatable, Sendable {
        var scale: Double
        var strength: Double
    }

    struct Bloom: Codable, Equatable, Sendable {
        var radius: Double
        var intensity: Double
    }

    struct Range: Codable, Equatable, Sendable {
        var min: Double
        var max: Double
    }

    struct Pattern: Codable, Equatable, Sendable {
        var caps: Caps
        var counts: Counts
        var regionWeights: [String: Double]
        var leftRightMaxDiff: Double
        var wristExtent: Double
    }

    struct Caps: Codable, Equatable, Sendable {
        var extent: [Double]
        var brightness: [Double]
    }

    struct Counts: Codable, Equatable, Sendable {
        var streak: Int
        var fleck: Int
        var patch: Int
    }

    struct Fade: Codable, Equatable, Sendable {
        var quickRinse: QuickRinse
        var wristPerRehearsal: Double
        var fadeInMs: Double
        var fadeOutMs: Double
    }

    struct QuickRinse: Codable, Equatable, Sendable {
        var palm: Double
    }

    struct Rehearsal: Codable, Equatable, Sendable {
        var stepSeconds: [Double]
        var pauseAfterMs: Double
    }

    struct Quality: Codable, Equatable, Sendable {
        var high: QualityLevelConfig
        var medium: QualityLevelConfig
        var low: QualityLevelConfig
    }

    struct QualityLevelConfig: Codable, Equatable, Sendable {
        var countScale: Double
        var bloomScale: Double
    }

    func weight(for region: GlowRegion) -> Double {
        pattern.regionWeights[region.rawValue] ?? 1.0
    }

    static func load(from bundle: Bundle = .main) throws -> LookConfig {
        guard let url = bundle.url(forResource: "look", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try decode(Data(contentsOf: url))
    }

    static func decode(_ data: Data) throws -> LookConfig {
        try JSONDecoder().decode(LookConfig.self, from: data)
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}

/// sRGB hex string ("#rrggbb") to linear-free 0…1 components, as stored in look.json.
func rgb(hex: String) -> SIMD3<Float> {
    var value: UInt64 = 0
    Scanner(string: hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))).scanHexInt64(&value)
    return SIMD3(Float((value >> 16) & 0xff), Float((value >> 8) & 0xff), Float(value & 0xff)) / 255
}
