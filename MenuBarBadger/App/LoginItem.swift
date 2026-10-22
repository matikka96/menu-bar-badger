import Foundation
import OSLog
import ServiceManagement

enum LoginItem {
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MenuBarBadger", category: "login")

    static var status: SMAppService.Status { SMAppService.mainApp.status }

    /// `status` is not a reliable test: it also gives `.notFound` for an app in /Applications when Launch Services
    /// knows other copies of the same bundle ID.
    static let isInApplicationsFolder: Bool = {
        let appPath = Bundle.main.bundleURL.resolvingSymlinksInPath().path
        return FileManager.default.urls(for: .applicationDirectory, in: [.localDomainMask, .userDomainMask])
            .contains { appPath.hasPrefix($0.resolvingSymlinksInPath().path + "/") }
    }()

    static func setEnabled(_ isEnabled: Bool) throws {
        do {
            if isEnabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            log.notice("Login item \(isEnabled ? "registered" : "unregistered", privacy: .public): status \(status.rawValue)")
        } catch {
            log.error("Login item change failed: \(String(describing: error), privacy: .public), status \(status.rawValue)")
            throw error
        }
    }

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
