import AppKit
import BadgerCore
import OSLog

final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MenuBarBadger", category: "config")

    private let model = AppModel()
    private var configStore: ConfigStore?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenu.make()
        NSApp.windowsMenu = NSApp.mainMenu?.items.last?.submenu

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

    func applicationWillTerminate(_ notification: Notification) {
        configStore?.stop()
    }
}
