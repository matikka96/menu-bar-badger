import AppKit

/// macOS forgets the position of a hidden item (FB9052637), so the app keeps its own backup.
struct ItemPosition {
    let bundleID: String
    private let defaults = UserDefaults.standard

    var autosaveName: String { "MenuBarBadger.\(bundleID)" }
    /// The distance from the right edge of the screen to the right edge of the item. The menu bar sorts by it.
    private var systemKey: String { "NSStatusItem Preferred Position \(autosaveName)" }
    private var visibilityKeys: [String] { ["NSStatusItem Visible \(autosaveName)", "NSStatusItem VisibleCC \(autosaveName)"] }
    private var backupKey: String { "MBB.position.\(bundleID)" }

    /// macOS saves a position only after the user moves the item. Items with no position go to the left of the
    /// others when they show again, so each item records its place once. Before macOS places the item, its window
    /// is at the left edge of the screen, where the Apple menu is.
    func recordIfMissing(itemWindow: NSWindow?) {
        guard defaults.object(forKey: systemKey) == nil,
              let itemWindow, let screen = itemWindow.screen, itemWindow.frame.minX > screen.frame.minX
        else { return }
        defaults.set(Double(screen.frame.maxX - itemWindow.frame.maxX), forKey: systemKey)
    }

    func backUp() {
        // Each write posts didChangeNotification, which calls backUp again.
        guard let position = defaults.object(forKey: systemKey) as? Double,
              defaults.object(forKey: backupKey) as? Double != position
        else { return }
        defaults.set(position, forKey: backupKey)
    }

    func restore() {
        guard let position = defaults.object(forKey: backupKey) else { return }
        defaults.set(position, forKey: systemKey)
    }

    func forget() {
        for key in [systemKey, backupKey] + visibilityKeys {
            defaults.removeObject(forKey: key)
        }
    }
}
