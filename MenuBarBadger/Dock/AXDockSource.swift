import AppKit
import ApplicationServices
import BadgerCore

/// The Dock through the Accessibility API. Only the `DockReader` actor calls it, so no element reaches the main thread.
nonisolated final class AXDockSource: DockSource {
    private static let dockBundleID = "com.apple.dock"
    private static let messagingTimeout: Float = 0.5
    private static let applicationDockItem = "AXApplicationDockItem"
    private static let statusLabel = "AXStatusLabel"

    private var dock: AXUIElement?
    private var dockProcessIDValue: Int32?
    private var observer: AXObserver?
    private var eventBox: Unmanaged<EventBox>?

    func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    func dockProcessID() -> Int32? {
        NSRunningApplication.runningApplications(withBundleIdentifier: Self.dockBundleID)
            .first { !$0.isTerminated }?
            .processIdentifier
    }

    func observe(processID: Int32, onEvent: @escaping @Sendable (DockEvent) -> Void) -> Bool {
        stopObserving()
        let dock = AXUIElementCreateApplication(processID)
        AXUIElementSetMessagingTimeout(dock, Self.messagingTimeout)
        self.dock = dock
        dockProcessIDValue = processID

        var created: AXObserver?
        guard AXObserverCreate(processID, Self.callback, &created) == .success, let created else { return false }
        let box = Unmanaged.passRetained(EventBox(onEvent))
        let refcon = box.toOpaque()
        let isAdded = [kAXCreatedNotification, kAXUIElementDestroyedNotification].allSatisfy {
            AXObserverAddNotification(created, dock, $0 as CFString, refcon) == .success
        }
        guard isAdded else {
            box.release()
            return false
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
        observer = created
        eventBox = box
        return true
    }

    func items() -> [(item: AXUIElement, description: DockItemDescription)] {
        guard let dock = currentDock() else { return [] }
        return children(of: dock)
            .flatMap(children(of:))
            .filter { string(kAXSubroleAttribute, of: $0) == Self.applicationDockItem }
            .map { ($0, DockItemDescription(bundleID: bundleID(of: $0), title: string(kAXTitleAttribute, of: $0))) }
    }

    func badge(of item: AXUIElement) throws(StaleDockItem) -> String {
        var value: CFTypeRef?
        switch AXUIElementCopyAttributeValue(item, Self.statusLabel as CFString, &value) {
        case .success: return value as? String ?? ""
        case .invalidUIElement, .cannotComplete: throw StaleDockItem()
        default: return ""
        }
    }

    private func currentDock() -> AXUIElement? {
        if let dock { return dock }
        guard let processID = dockProcessIDValue ?? dockProcessID() else { return nil }
        let dock = AXUIElementCreateApplication(processID)
        AXUIElementSetMessagingTimeout(dock, Self.messagingTimeout)
        self.dock = dock
        return dock
    }

    /// The main run loop delivers the callbacks, so the source goes away and the box is freed there, after them.
    private func stopObserving() {
        guard let observer, let eventBox else { return }
        nonisolated(unsafe) let source = AXObserverGetRunLoopSource(observer)
        nonisolated(unsafe) let box = eventBox
        DispatchQueue.main.async {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            box.release()
        }
        self.observer = nil
        self.eventBox = nil
    }

    private func children(of element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success else { return [] }
        let children = value as? [AXUIElement] ?? []
        for child in children {
            AXUIElementSetMessagingTimeout(child, Self.messagingTimeout)
        }
        return children
    }

    private func string(_ attribute: String, of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private func bundleID(of item: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(item, kAXURLAttribute as CFString, &value) == .success,
              let url = value as? URL
        else { return nil }
        return Bundle(url: url)?.bundleIdentifier
    }

    private static let callback: AXObserverCallback = { _, _, notification, refcon in
        guard let refcon else { return }
        let box = Unmanaged<EventBox>.fromOpaque(refcon).takeUnretainedValue()
        box.onEvent(notification as String == kAXCreatedNotification ? .elementCreated : .elementDestroyed)
    }
}

private nonisolated final class EventBox {
    let onEvent: @Sendable (DockEvent) -> Void

    init(_ onEvent: @escaping @Sendable (DockEvent) -> Void) {
        self.onEvent = onEvent
    }
}
