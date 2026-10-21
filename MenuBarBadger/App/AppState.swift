import AppKit
import BadgerCore

struct AppState: Sendable, Equatable, Identifiable {
    let bundleID: String
    var name: String
    /// Nil when no app with this bundle ID is installed.
    var appURL: URL?
    var isRunning = false
    var isActive = false
    var badge = ""
    var isDockItemFound = false

    var id: String { bundleID }
    var isInstalled: Bool { appURL != nil }

    init(bundleID: String) {
        self.bundleID = bundleID
        name = bundleID
        refreshInstalledApp()
        refreshRunningState()
    }

    mutating func refreshInstalledApp() {
        appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        name = appURL.map(Self.displayName(of:)) ?? bundleID
    }

    mutating func refreshRunningState() {
        let instances = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { !$0.isTerminated }
        isRunning = !instances.isEmpty
        isActive = instances.contains(where: \.isActive)
    }

    private static func displayName(of appURL: URL) -> String {
        let bundleName = (try? appURL.resourceValues(forKeys: [.localizedNameKey]).localizedName)
            ?? appURL.lastPathComponent
        return DisplayName.fromBundleName(bundleName)
    }
}
