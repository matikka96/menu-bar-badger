import Foundation

/// The Debug launch arguments. A Release build ignores them.
enum LaunchOptions {
    static var skipsSetup: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "MBBSkipSetup")
        #else
        false
        #endif
    }

    static var fakeDockFile: URL? {
        fileURL(forKey: "MBBFakeDock")
    }

    static var stateFile: URL? {
        fileURL(forKey: "MBBStateFile")
    }

    private static func fileURL(forKey key: String) -> URL? {
        #if DEBUG
        UserDefaults.standard.string(forKey: key).map {
            URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath)
        }
        #else
        nil
        #endif
    }
}
