import Foundation

enum QualityLevel: String, CaseIterable, Comparable, Codable, Sendable {
    case low, medium, high

    static func < (a: QualityLevel, b: QualityLevel) -> Bool {
        allCases.firstIndex(of: a)! < allCases.firstIndex(of: b)!
    }

    func config(in look: LookConfig) -> LookConfig.QualityLevelConfig {
        switch self {
        case .high: look.quality.high
        case .medium: look.quality.medium
        case .low: look.quality.low
        }
    }
}

/// Reduces visual detail before the glow can lag (research R2, R8): if GPU frame time stays over
/// budget, it steps high → medium → low, and steps back up once there is plenty of headroom.
struct QualityController {
    private(set) var level: QualityLevel = .high
    var budget: Double
    var stepDownAfter: Double = 2
    var stepUpAfter: Double = 10

    private var average: Double = 0
    private var overSince: Double?
    private var underSince: Double?

    init(targetFPS: Double = 60) {
        budget = 0.8 / targetFPS
    }

    /// Feeds one frame's GPU time. Returns the new level when it changes.
    mutating func record(frameSeconds: Double, at time: Double) -> QualityLevel? {
        average = average == 0 ? frameSeconds : average * 0.95 + frameSeconds * 0.05
        if average > budget {
            underSince = nil
            if overSince == nil { overSince = time }
            if let since = overSince, time - since >= stepDownAfter, level > .low {
                level = QualityLevel.allCases[QualityLevel.allCases.firstIndex(of: level)! - 1]
                overSince = nil
                return level
            }
        } else if average < budget * 0.5 {
            overSince = nil
            if underSince == nil { underSince = time }
            if let since = underSince, time - since >= stepUpAfter, level < .high {
                level = QualityLevel.allCases[QualityLevel.allCases.firstIndex(of: level)! + 1]
                underSince = nil
                return level
            }
        } else {
            overSince = nil
            underSince = nil
        }
        return nil
    }
}
