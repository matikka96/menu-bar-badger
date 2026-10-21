import AppKit
import BadgerCore
import Observation
import OSLog

final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MenuBarBadger", category: "config")
    private static let dockLog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MenuBarBadger", category: "dock")

    private let model = AppModel()
    private let settingsWindow = SettingsWindowController()
    private var configStore: ConfigStore?
    private var reader: (any DockReading)?
    private var menuBar: MenuBarController?
    private var runningApps: RunningApps?
    private var welcomeWindow: WelcomeWindowController?
    private var tasks: [Task<Void, Never>] = []
    private var screenObservers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenu.make()
        NSApp.windowsMenu = NSApp.mainMenu?.items.last?.submenu

        let isFirstLaunch = !FileManager.default.fileExists(atPath: ConfigLocation.fileURL.path)
        startConfigStore()

        let openSettings: (SettingsRequest) -> Void = { [settingsWindow] in settingsWindow.open($0) }
        let menuBar = MenuBarController(model: model, openSettings: openSettings)
        menuBar.start()
        self.menuBar = menuBar

        let reader = makeReader()
        self.reader = reader
        startReader(reader, isFirstLaunch: isFirstLaunch)

        let runningApps = RunningApps(model: model, reader: reader)
        runningApps.start()
        self.runningApps = runningApps
        observeScreenSleep(reader)

        if isFirstLaunch && !LaunchOptions.skipsWelcome {
            let welcome = WelcomeWindowController(model: model, openSettings: openSettings)
            welcome.show()
            welcomeWindow = welcome
        } else if model.config.apps.isEmpty {
            settingsWindow.open(.apps(selecting: nil))
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        configStore?.stop()
    }

    private func startConfigStore() {
        let model = model
        let store = ConfigStore(fileURL: ConfigLocation.fileURL) { result in
            model.apply(result)
            switch result {
            case .success(let config): Self.log.info("Config applied: \(config.apps.count) apps")
            case .failure(let error): Self.log.error("Config error: \(String(describing: error))")
            }
        }
        store.start()
        configStore = store
    }

    private func makeReader() -> any DockReading {
        #if DEBUG
        if let fakeDockFile = LaunchOptions.fakeDockFile {
            return DockReader(source: FakeDockSource(fileURL: fakeDockFile))
        }
        #endif
        return DockReader(source: AXDockSource())
    }

    private func startReader(_ reader: any DockReading, isFirstLaunch: Bool) {
        let model = model
        let settingsWindow = settingsWindow
        tasks.append(Task {
            var hasCheckedPermission = false
            for await event in reader.events {
                switch event {
                case .permission(let isTrusted):
                    Self.dockLog.info("Accessibility permission: \(isTrusted)")
                    model.setTrusted(isTrusted)
                    if !hasCheckedPermission, !isTrusted, !isFirstLaunch {
                        settingsWindow.open(.lastTab)
                    }
                    hasCheckedPermission = true
                case .states(let states):
                    Self.dockLog.debug("Badge changes: \(states.count)")
                    model.apply(states)
                }
            }
        })
        tasks.append(Task {
            for await apps in Observations({ model.apps.map { MonitoredDockApp(bundleID: $0.bundleID, displayName: $0.name) } }) {
                await reader.setApps(apps)
            }
        })
        Task { await reader.start() }
    }

    /// One task forwards the events, so that a fast sleep and wake reach the reader in order.
    private func observeScreenSleep(_ reader: any DockReading) {
        let (sleepStates, continuation) = AsyncStream<Bool>.makeStream()
        let center = NSWorkspace.shared.notificationCenter
        screenObservers = [
            center.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { _ in
                continuation.yield(true)
            },
            center.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { _ in
                continuation.yield(false)
            },
        ]
        tasks.append(Task {
            for await areScreensAsleep in sleepStates {
                await reader.setScreensAsleep(areScreensAsleep)
            }
        })
    }
}
