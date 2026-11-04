import UIKit

/// The iPad settings that change what a participant sees (002 FR-025, research D17). Study sessions
/// run with one fixed profile, so every participant gets the same intervention (Principle III).
struct StudySettings: Sendable, Equatable, Codable {
    var reduceMotion: Bool
    var reduceTransparency: Bool
    var increaseContrast: Bool
    var textSize: String
    var osVersion: String

    /// The study profile: no accessibility changes to motion or surfaces, default text size.
    var matchesProfile: Bool {
        !reduceMotion && !reduceTransparency && !increaseContrast
            && textSize == UIContentSizeCategory.large.rawValue
    }

    /// What differs from the study profile, for the facilitator's warning.
    var deviations: [String] {
        var list: [String] = []
        if reduceMotion { list.append("Reduce Motion is on") }
        if reduceTransparency { list.append("Reduce Transparency is on") }
        if increaseContrast { list.append("Increase Contrast is on") }
        if textSize != UIContentSizeCategory.large.rawValue { list.append("Text size is not the default") }
        return list
    }

    @MainActor
    static func current() -> StudySettings {
        StudySettings(
            reduceMotion: UIAccessibility.isReduceMotionEnabled,
            reduceTransparency: UIAccessibility.isReduceTransparencyEnabled,
            increaseContrast: UIAccessibility.isDarkerSystemColorsEnabled,
            textSize: UIApplication.shared.preferredContentSizeCategory.rawValue,
            osVersion: UIDevice.current.systemVersion
        )
    }
}
