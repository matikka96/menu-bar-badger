import AppKit
import ApplicationServices
import BadgerCore

/// Both rules are heuristics: an app that fakes full screen without the system full-screen mode does not count.
enum MenuBarCheck {
    private nonisolated static let messagingTimeout: Float = 0.5
    private nonisolated static let fullScreenAttribute = "AXFullScreen"

    static func screen(ofItem itemWindow: NSWindow) -> NSScreen? {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return nil }
        if let screen = itemWindow.screen { return screen }
        return screens[ScreenGeometry.screen(ofItem: itemWindow.frame, in: screens.map(\.frame))]
    }

    static func isMenuBarHidden(on screen: NSScreen) async -> Bool {
        if ScreenGeometry.isMenuBarAutoHidden(screenFrame: screen.frame, visibleFrame: screen.visibleFrame) { return true }
        guard let frontmost = NSWorkspace.shared.frontmostApplication else { return false }
        let windows = await fullScreenWindowFrames(processID: frontmost.processIdentifier)
        let screens = NSScreen.screens
        guard let target = screens.firstIndex(of: screen) else { return false }
        let frames = screens.map(\.frame)
        return windows.contains { window in
            let rect = ScreenGeometry.appKitRect(fromAccessibility: window, mainScreenHeight: frames[0].height)
            return ScreenGeometry.screen(holdingLargestPartOf: rect, in: frames) == target
        }
    }

    /// In the Accessibility coordinates. Runs off the main actor, so a hung app cannot block the main thread.
    @concurrent
    private nonisolated static func fullScreenWindowFrames(processID: pid_t) async -> [CGRect] {
        let app = AXUIElementCreateApplication(processID)
        AXUIElementSetMessagingTimeout(app, messagingTimeout)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement]
        else { return [] }
        return windows.compactMap { window in
            AXUIElementSetMessagingTimeout(window, messagingTimeout)
            guard attribute(fullScreenAttribute, of: window) as? Bool == true,
                  let position = point(kAXPositionAttribute, of: window),
                  let size = size(kAXSizeAttribute, of: window)
            else { return nil }
            return CGRect(origin: position, size: size)
        }
    }

    private nonisolated static func attribute(_ name: String, of element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    private nonisolated static func point(_ name: String, of element: AXUIElement) -> CGPoint? {
        guard let value = attribute(name, of: element), CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        return AXValueGetValue(value as! AXValue, .cgPoint, &point) ? point : nil
    }

    private nonisolated static func size(_ name: String, of element: AXUIElement) -> CGSize? {
        guard let value = attribute(name, of: element), CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var size = CGSize.zero
        return AXValueGetValue(value as! AXValue, .cgSize, &size) ? size : nil
    }
}
