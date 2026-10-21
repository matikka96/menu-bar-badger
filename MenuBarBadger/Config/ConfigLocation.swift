import AppKit

enum ConfigLocation {
    static var fileURL: URL {
        #if DEBUG
        if let path = UserDefaults.standard.string(forKey: "MBBConfigFile") {
            return URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        }
        #endif
        return folderURL.appending(path: fileName)
    }

    static var displayPath: String {
        (fileURL.path as NSString).abbreviatingWithTildeInPath
    }

    /// Selects the file in Finder, or opens its folder when the file is missing.
    static func showInFinder() {
        let url = fileURL
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            NSWorkspace.shared.open(url.deletingLastPathComponent())
        }
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
