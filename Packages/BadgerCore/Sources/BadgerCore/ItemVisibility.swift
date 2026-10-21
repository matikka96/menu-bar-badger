import Foundation

public enum ItemVisibility {
    public static func isHidden(badge: String, isRunning: Bool, config: Config) -> Bool {
        (config.whenNothingNew == .hide && badge.isEmpty) || (config.hideWhenNotRunning && !isRunning)
    }
}
