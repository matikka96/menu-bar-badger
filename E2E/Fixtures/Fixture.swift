import AppKit

// The runner builds this source into each fixture app with its own Info.plist. `MBBFixtureControlFile` holds
// the path of the badge text. `MBBFixtureReportFile`, only in app Text, holds the path where the app reports the
// typed text and the clicks.

final class FixtureDelegate: NSObject, NSApplicationDelegate {
    private static let pollInterval: TimeInterval = 0.2

    private let controlFile: URL
    private let window: NSWindow?
    private let showsWindowAtLaunch: Bool
    private var timer: Timer?

    init(controlFile: URL, window: NSWindow?, showsWindowAtLaunch: Bool) {
        self.controlFile = controlFile
        self.window = window
        self.showsWindowAtLaunch = showsWindowAtLaunch
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        window?.center()
        if showsWindowAtLaunch {
            window?.makeKeyAndOrderFront(nil)
        }
        timer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.showBadge() }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        window?.makeKeyAndOrderFront(nil)
        return false
    }

    private func showBadge() {
        let text = (try? String(contentsOf: controlFile, encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let label = text.isEmpty ? nil : text
        if NSApp.dockTile.badgeLabel != label {
            NSApp.dockTile.badgeLabel = label
        }
    }
}

/// A window with one text field. It reports the text and the count of mouse-down events in the app.
final class TextWindow: NSObject {
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 480, height: 160),
        styleMask: [.titled, .resizable, .miniaturizable], backing: .buffered, defer: false
    )
    private let field = NSTextField()
    private let reportFile: URL
    private var clicks = 0
    private var monitor: Any?

    init(title: String, reportFile: URL) {
        self.reportFile = reportFile
        super.init()
        window.title = title
        window.isRestorable = false
        window.collectionBehavior = .fullScreenPrimary
        field.frame = window.contentLayoutRect.insetBy(dx: 20, dy: 20)
        field.autoresizingMask = [.width, .height]
        window.contentView?.addSubview(field)
        window.initialFirstResponder = field
        NotificationCenter.default.addObserver(
            self, selector: #selector(report), name: NSControl.textDidChangeNotification, object: field
        )
        monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.clicks += 1
            self?.report()
            return event
        }
        report()
    }

    @objc private func report() {
        let report: [String: Any] = ["text": field.stringValue, "clicks": clicks]
        try? JSONSerialization.data(withJSONObject: report).write(to: reportFile, options: .atomic)
    }
}

let info = Bundle.main.infoDictionary ?? [:]
guard let controlPath = info["MBBFixtureControlFile"] as? String else {
    fatalError("The Info.plist has no MBBFixtureControlFile")
}
let title = info["CFBundleDisplayName"] as? String ?? info["CFBundleName"] as? String ?? "Fixture"
let isAgent = info["LSUIElement"] as? Bool == true
let textWindow = (info["MBBFixtureReportFile"] as? String).map {
    TextWindow(title: title, reportFile: URL(fileURLWithPath: $0))
}
// An agent app needs a window: a click on its item must show it, and a second click must hide it. The window
// shows only on a reopen, so that the first click proves the show.
let window = textWindow?.window ?? (isAgent ? NSWindow(
    contentRect: NSRect(x: 0, y: 0, width: 240, height: 80), styleMask: [.titled], backing: .buffered, defer: false
) : nil)
window?.title = title
window?.isRestorable = false

let app = NSApplication.shared
let delegate = FixtureDelegate(
    controlFile: URL(fileURLWithPath: controlPath), window: window, showsWindowAtLaunch: textWindow != nil
)
app.delegate = delegate
app.setActivationPolicy(isAgent ? .accessory : .regular)
app.run()
