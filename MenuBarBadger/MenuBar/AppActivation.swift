import AppKit
import ApplicationServices

enum AppActivation {
    static func toggle(bundleID: String, appURL: URL?) {
        guard let active = instances(of: bundleID).first(where: \.isActive) else {
            open(bundleID: bundleID, appURL: appURL)
            return
        }
        // An agent app with no Dock icon refuses a normal hide.
        if active.activationPolicy == .regular, active.hide() { return }
        let processID = active.processIdentifier
        Task.detached {
            AXUIElementSetAttributeValue(AXUIElementCreateApplication(processID), "AXHidden" as CFString, kCFBooleanTrue)
        }
    }

    /// Opens the app as a Dock click does: LaunchServices activates the running instance and sends it a reopen.
    static func open(bundleID: String, appURL: URL?) {
        guard let url = instances(of: bundleID).first?.bundleURL ?? appURL else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    }

    private static func instances(of bundleID: String) -> [NSRunningApplication] {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).filter { !$0.isTerminated }
    }
}
