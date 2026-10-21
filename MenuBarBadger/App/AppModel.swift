import BadgerCore
import Observation
import OSLog
import ServiceManagement

@Observable
final class AppModel {
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MenuBarBadger", category: "config")

    private(set) var config = Config()
    private(set) var configError: ConfigError?
    private(set) var apps: [AppState] = []
    /// Nil until the Dock reader checks the permission for the first time.
    private(set) var isTrusted: Bool?
    private(set) var loginItemStatus = LoginItem.status

    var selectedBundleID: String?
    var isAddSheetPresented = false
    let catalog = AppCatalog()

    @ObservationIgnored var configStore: ConfigStore?

    var canChangeConfig: Bool { configError == nil }

    func apply(_ result: Result<Config, ConfigError>) {
        switch result {
        case .success(let config):
            self.config = config
            configError = nil
            syncApps()
        case .failure(let error):
            configError = error
        }
    }

    func apply(_ states: [String: DockAppState]) {
        for index in apps.indices {
            guard let state = states[apps[index].bundleID] else { continue }
            apps[index].badge = state.badge
            apps[index].isDockItemFound = state.isDockItemFound
        }
    }

    func setTrusted(_ isTrusted: Bool) {
        self.isTrusted = isTrusted
    }

    func refreshInstalledApps() {
        for index in apps.indices {
            apps[index].refreshInstalledApp()
        }
    }

    func refreshRunningStates() {
        for index in apps.indices {
            apps[index].refreshRunningState()
        }
    }

    func refreshLoginItemStatus() {
        loginItemStatus = LoginItem.status
    }

    func settings(of bundleID: String) -> MonitoredApp? {
        config.apps.first { $0.bundleID == bundleID }
    }

    /// Writes the changed config to the file and applies it at once. Does nothing in the error state.
    func changeConfig(_ change: (inout Config) -> Void) {
        guard let configStore, canChangeConfig else { return }
        var changed = config
        change(&changed)
        guard changed != config else { return }
        do {
            try configStore.save(changed)
            apply(.success(changed))
        } catch {
            Self.log.error("Config write failed: \(String(describing: error))")
        }
    }

    func changeApp(_ bundleID: String, _ change: (inout MonitoredApp) -> Void) {
        changeConfig { config in
            guard let index = config.apps.firstIndex(where: { $0.bundleID == bundleID }) else { return }
            change(&config.apps[index])
        }
    }

    func addApp(bundleID: String, name: String) {
        changeConfig { config in
            guard !config.apps.contains(where: { $0.bundleID == bundleID }) else { return }
            config.apps.append(MonitoredApp(bundleID: bundleID, name: name))
        }
        if settings(of: bundleID) != nil {
            selectedBundleID = bundleID
        }
    }

    func removeApp(_ bundleID: String) {
        changeConfig { $0.apps.removeAll { $0.bundleID == bundleID } }
        selectedBundleID = nil
    }

    func reloadConfig() {
        configStore?.reload()
    }

    func createMissingConfigFile() {
        do {
            try configStore?.createMissingFile(with: config)
        } catch {
            Self.log.error("Config create failed: \(String(describing: error))")
        }
    }

    private func syncApps() {
        let existing = Dictionary(uniqueKeysWithValues: apps.map { ($0.bundleID, $0) })
        apps = config.apps.map { existing[$0.bundleID] ?? AppState(bundleID: $0.bundleID) }
        if let selectedBundleID, settings(of: selectedBundleID) == nil {
            self.selectedBundleID = nil
        }
    }
}
