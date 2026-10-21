import AppKit
import BadgerCore
import Observation

/// Keeps exactly one item for each monitored app.
final class MenuBarController {
    private struct Input: Sendable, Equatable {
        var apps: [AppState]
        var config: Config
    }

    private let model: AppModel
    private let openSettings: (SettingsRequest) -> Void
    private let onItemClick: (String) -> Void
    private var items: [String: StatusItemController] = [:]
    private var observation: Task<Void, Never>?

    init(model: AppModel, openSettings: @escaping (SettingsRequest) -> Void, onItemClick: @escaping (String) -> Void) {
        self.model = model
        self.openSettings = openSettings
        self.onItemClick = onItemClick
    }

    func itemWindow(of bundleID: String) -> NSWindow? {
        items[bundleID]?.itemWindow
    }

    #if DEBUG
    var debugItems: [DebugState.Item] {
        model.apps.compactMap { items[$0.bundleID]?.debugItem }
    }
    #endif

    func start() {
        sync()
        let model = model
        observation = Task { [weak self] in
            for await _ in Observations({ Input(apps: model.apps, config: model.config) }) {
                self?.sync()
            }
        }
    }

    private func sync() {
        let monitored = Set(model.apps.map(\.bundleID))
        for (bundleID, item) in items where !monitored.contains(bundleID) {
            item.remove()
            items[bundleID] = nil
        }
        for app in model.apps {
            guard let settings = model.settings(of: app.bundleID) else { continue }
            if let item = items[app.bundleID] {
                item.update(state: app, settings: settings, config: model.config)
            } else {
                items[app.bundleID] = StatusItemController(
                    state: app, settings: settings, config: model.config,
                    openSettings: openSettings, onClick: onItemClick
                )
            }
        }
    }
}
