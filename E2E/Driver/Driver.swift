import AppKit
import ApplicationServices

// The e2e runner calls this tool for each read of the system and each input event. Each command prints one
// JSON object. All points and rectangles use the Quartz coordinates: the origin at the top left of the main
// display, and y down.

let usage = """
    usage: driver dock | app BUNDLE_ID | screens | click X Y | type TEXT
                  | window PID | fullscreen PID on|off | place PID X Y WIDTH HEIGHT
    """

func output(_ object: Any) {
    let data = try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    print(String(decoding: data, as: UTF8.self))
}

func fail(_ message: String) -> Never {
    output(["error": message])
    exit(1)
}

func json(_ rect: CGRect) -> [String: Double] {
    ["x": rect.minX, "y": rect.minY, "width": rect.width, "height": rect.height]
}

func value(_ attribute: String, of element: AXUIElement) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
    return value
}

func children(of element: AXUIElement) -> [AXUIElement] {
    value(kAXChildrenAttribute, of: element) as? [AXUIElement] ?? []
}

func runningApps(_ bundleID: String) -> [NSRunningApplication] {
    NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).filter { !$0.isTerminated }
}

func dock() -> [String: Any] {
    guard let processID = runningApps("com.apple.dock").first?.processIdentifier else {
        return ["trusted": AXIsProcessTrusted(), "items": []]
    }
    let items = children(of: AXUIElementCreateApplication(processID))
        .flatMap(children(of:))
        .filter { value(kAXSubroleAttribute, of: $0) as? String == "AXApplicationDockItem" }
        .map { item -> [String: Any] in
            let url = value(kAXURLAttribute, of: item) as? URL
            return [
                "bundleID": url.flatMap { Bundle(url: $0)?.bundleIdentifier } ?? NSNull(),
                "title": value(kAXTitleAttribute, of: item) as? String ?? NSNull(),
                "badge": value("AXStatusLabel", of: item) as? String ?? "",
            ]
        }
    return ["trusted": AXIsProcessTrusted(), "dockProcessID": Int(processID), "items": items]
}

func onScreenWindowCount(of processID: pid_t) -> Int {
    let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
        as? [[String: Any]] ?? []
    return windows.filter {
        $0[kCGWindowOwnerPID as String] as? Int == Int(processID) && $0[kCGWindowLayer as String] as? Int == 0
    }.count
}

func appState(_ bundleID: String) -> [String: Any] {
    let apps = runningApps(bundleID)
    return [
        "processIDs": apps.map { Int($0.processIdentifier) },
        "isActive": apps.contains(where: \.isActive),
        "isHidden": apps.contains(where: \.isHidden),
        "isFrontmost": NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleID,
        "windowsOnScreen": apps.map { onScreenWindowCount(of: $0.processIdentifier) }.reduce(0, +),
    ]
}

func screens() -> [[String: Double]] {
    var count: UInt32 = 0
    CGGetActiveDisplayList(0, nil, &count)
    var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
    CGGetActiveDisplayList(count, &displays, &count)
    let main = CGMainDisplayID()
    return displays.sorted { ($0 == main ? 0 : 1) < ($1 == main ? 0 : 1) }.map { json(CGDisplayBounds($0)) }
}

func post(_ event: CGEvent?) {
    event?.post(tap: .cghidEventTap)
}

func click(at point: CGPoint) {
    post(CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left))
    Thread.sleep(forTimeInterval: 0.1)
    post(CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left))
    Thread.sleep(forTimeInterval: 0.05)
    post(CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left))
}

func type(_ text: String) {
    for character in text {
        let units = Array(String(character).utf16)
        for isDown in [true, false] {
            let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: isDown)
            event?.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
            post(event)
        }
        Thread.sleep(forTimeInterval: 0.03)
    }
}

func mainWindow(of processID: pid_t) -> AXUIElement {
    let app = AXUIElementCreateApplication(processID)
    if let main = value(kAXMainWindowAttribute, of: app), CFGetTypeID(main) == AXUIElementGetTypeID() {
        return main as! AXUIElement
    }
    guard let first = (value(kAXWindowsAttribute, of: app) as? [AXUIElement])?.first else {
        fail("The app \(processID) has no window")
    }
    return first
}

func windowState(_ window: AXUIElement) -> [String: Any] {
    var origin = CGPoint.zero
    var size = CGSize.zero
    if let position = value(kAXPositionAttribute, of: window) {
        AXValueGetValue(position as! AXValue, .cgPoint, &origin)
    }
    if let sizeValue = value(kAXSizeAttribute, of: window) {
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
    }
    return ["isFullScreen": value("AXFullScreen", of: window) as? Bool ?? false, "frame": json(CGRect(origin: origin, size: size))]
}

func set(_ attribute: String, of window: AXUIElement, to newValue: CFTypeRef) {
    let result = AXUIElementSetAttributeValue(window, attribute as CFString, newValue)
    guard result == .success else { fail("The set of \(attribute) failed with the code \(result.rawValue)") }
}

let arguments = Array(CommandLine.arguments.dropFirst())

func number(_ index: Int) -> Double {
    guard index < arguments.count, let number = Double(arguments[index]) else { fail(usage) }
    return number
}

func processID(_ index: Int) -> pid_t { pid_t(number(index)) }
func point(_ index: Int) -> CGPoint { CGPoint(x: number(index), y: number(index + 1)) }

switch (arguments.first, arguments.count) {
case ("dock", 1):
    output(dock())
case ("app", 2):
    output(appState(arguments[1]))
case ("screens", 1):
    output(["screens": screens()])
case ("click", 3):
    click(at: point(1))
    output([:])
case ("type", 2):
    type(arguments[1])
    output([:])
case ("window", 2):
    output(windowState(mainWindow(of: processID(1))))
case ("fullscreen", 3) where ["on", "off"].contains(arguments[2]):
    set("AXFullScreen", of: mainWindow(of: processID(1)), to: (arguments[2] == "on" ? kCFBooleanTrue : kCFBooleanFalse)!)
    output([:])
case ("place", 6):
    let window = mainWindow(of: processID(1))
    var origin = point(2)
    var size = CGSize(width: number(4), height: number(5))
    set(kAXPositionAttribute, of: window, to: AXValueCreate(.cgPoint, &origin)!)
    set(kAXSizeAttribute, of: window, to: AXValueCreate(.cgSize, &size)!)
    output(windowState(window))
default:
    fail(usage)
}
