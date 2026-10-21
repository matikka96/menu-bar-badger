import Foundation

/// The Debug launch arguments. A Release build ignores them.
enum LaunchOptions {
    static var skipsWelcome: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "MBBSkipWelcome")
        #else
        false
        #endif
    }

    static var fakeDockFile: URL? {
        #if DEBUG
        UserDefaults.standard.string(forKey: "MBBFakeDock").map {
            URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath)
        }
        #else
        nil
        #endif
    }
}
