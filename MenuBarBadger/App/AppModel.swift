import BadgerCore
import Observation

@Observable
final class AppModel {
    private(set) var config = Config()
    private(set) var configError: ConfigError?
    private(set) var apps: [AppState] = []
    /// Nil until the Dock reader checks the permission for the first time.
    private(set) var isTrusted: Bool?

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

    func settings(of bundleID: String) -> MonitoredApp? {
        config.apps.first { $0.bundleID == bundleID }
    }

    private func syncApps() {
        let existing = Dictionary(uniqueKeysWithValues: apps.map { ($0.bundleID, $0) })
        apps = config.apps.map { existing[$0.bundleID] ?? AppState(bundleID: $0.bundleID) }
    }
}
