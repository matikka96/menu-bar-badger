import AppKit
import BadgerCore
import Observation
import OSLog

final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MenuBarBadger", category: "config")
    private static let dockLog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MenuBarBadger", category: "dock")

    private let model = AppModel()
    private lazy var settingsWindow = SettingsWindowController(model: model)
    private lazy var globalShortcut = GlobalShortcut(model: model)
    private var configStore: ConfigStore?
    private var reader: (any DockReading)?
    private var menuBar: MenuBarController?
    private var attention: AttentionController?
    private var runningApps: RunningApps?
    private var welcomeWindow: WelcomeWindowController?
    #if DEBUG
    private var stateWriter: DebugStateWriter?
    #endif
    private var tasks: [Task<Void, Never>] = []
    private var screenObservers: [NSObjectProtocol] = []
    private var hasBeenActive = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenu.make()
        NSApp.windowsMenu = NSApp.mainMenu?.items.last?.submenu

        let isFirstLaunch = !FileManager.default.fileExists(atPath: ConfigLocation.fileURL.path)
        startConfigStore()
        let settingsWindow = settingsWindow
        globalShortcut.start { settingsWindow.open(.lastTab) }

        let openSettings: (SettingsRequest) -> Void = { [settingsWindow] in settingsWindow.open($0) }
        let attention = AttentionController(model: model)
        let menuBar = MenuBarController(model: model, openSettings: openSettings) { attention.dismiss(bundleID: $0) }
        menuBar.start()
        self.menuBar = menuBar
        attention.start { [weak menuBar] in menuBar?.itemWindow(of: $0) }
        self.attention = attention

        let reader = makeReader()
        self.reader = reader
        startReader(reader, isFirstLaunch: isFirstLaunch)

        let runningApps = RunningApps(model: model, reader: reader)
        runningApps.start()
        self.runningApps = runningApps
        observeScreenSleep(reader)
        #if DEBUG
        startStateWriter(menuBar: menuBar, attention: attention)
        #endif

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

    /// A launch from Finder or Spotlight activates the app. A launch at login or in the background does not.
    func applicationDidBecomeActive(_ notification: Notification) {
        model.refreshLoginItemStatus()
        guard !hasBeenActive else { return }
        hasBeenActive = true
        if welcomeWindow?.isVisible != true {
            settingsWindow.open(.lastTab)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settingsWindow.open(.lastTab)
        return false
    }

    @objc func showSettings(_ sender: Any?) {
        settingsWindow.open(.lastTab)
    }

    @objc func showAboutPanel(_ sender: Any?) {
        AboutPanel.show()
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
        model.configStore = store
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

    #if DEBUG
    private func startStateWriter(menuBar: MenuBarController, attention: AttentionController) {
        guard let fileURL = LaunchOptions.stateFile else { return }
        let model = model
        let writer = DebugStateWriter(fileURL: fileURL) {
            DebugState(
                processID: ProcessInfo.processInfo.processIdentifier,
                isTrusted: model.isTrusted,
                items: menuBar.debugItems,
                alerts: attention.debugAlerts,
                arrows: attention.debugArrows
            )
        }
        writer.start()
        stateWriter = writer
    }
    #endif

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
