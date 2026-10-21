import AppKit
import BadgerCore

final class RunningApps {
    private let model: AppModel
    private let reader: any DockReading
    private var observers: [NSObjectProtocol] = []

    init(model: AppModel, reader: any DockReading) {
        self.model = model
        self.reader = reader
    }

    func start() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let bundleID = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
                MainActor.assumeIsolated { self?.appDidLaunchOrTerminate(bundleID: bundleID) }
            })
        }
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.didDeactivateApplicationNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.model.refreshRunningStates() }
            })
        }
    }

    private func appDidLaunchOrTerminate(bundleID: String?) {
        model.refreshInstalledApps()
        model.refreshRunningStates()
        guard let bundleID, model.apps.contains(where: { $0.bundleID == bundleID }) else { return }
        let reader = reader
        Task { await reader.appDidLaunchOrTerminate(bundleID: bundleID) }
    }
}
