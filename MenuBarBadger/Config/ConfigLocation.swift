import Foundation

enum ConfigLocation {
    static var fileURL: URL {
        #if DEBUG
        if let path = UserDefaults.standard.string(forKey: "MBBConfigFile") {
            return URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        }
        #endif
        return folderURL.appending(path: fileName)
    }

    private static var folderURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appending(path: ".MenuBarBadger")
    }

    private static var fileName: String {
        #if DEBUG
        "dev.config.json"
        #else
        "config.json"
        #endif
    }
}
