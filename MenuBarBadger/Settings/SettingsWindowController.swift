import OSLog

enum SettingsRequest: Equatable {
    case lastTab
    case apps(selecting: String?)
    case addApp
}

/// A stub until the settings window exists (issue #3).
final class SettingsWindowController {
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MenuBarBadger", category: "settings")

    func open(_ request: SettingsRequest) {
        Self.log.info("Settings window requested: \(String(describing: request))")
    }
}
