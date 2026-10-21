import AppKit
import ApplicationServices

enum AccessibilityPermission {
    private static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!

    /// Adds the app to the list in System Settings, so the user only needs to turn on the switch, then opens that list.
    static func requestInSystemSettings() {
        Task {
            await addToSystemSettingsList()
            NSWorkspace.shared.open(settingsURL)
        }
    }

    @concurrent
    private static func addToSystemSettingsList() async {
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }
}
