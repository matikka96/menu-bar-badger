import AppKit
import BadgerCore

final class StatusItemController: NSObject {
    private struct Appearance: Equatable {
        var isVisible: Bool
        var face: ItemFace.Look
        var isDimmed: Bool
        var toolTip: String?
        var accessibilityLabel: String
    }

    private let statusItem: NSStatusItem
    private let position: ItemPosition
    private let face = ItemFace()
    private let openSettings: (SettingsRequest) -> Void
    private let onClick: (String) -> Void
    private var state: AppState
    private var settings: MonitoredApp
    private var config: Config
    private var pendingSettingsRequest: SettingsRequest?
    private var appearance: Appearance?
    #if DEBUG
    private var redrawCount = 0
    #endif
    private var backingObserver: NSObjectProtocol?
    private var defaultsObserver: NSObjectProtocol?

    init(
        state: AppState, settings: MonitoredApp, config: Config,
        openSettings: @escaping (SettingsRequest) -> Void, onClick: @escaping (String) -> Void
    ) {
        self.state = state
        self.settings = settings
        self.config = config
        self.openSettings = openSettings
        self.onClick = onClick
        position = ItemPosition(bundleID: state.bundleID)
        position.restore()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = position.autosaveName
        super.init()
        setUpButton()
        redraw()
    }

    /// Nil while the item is hidden.
    var itemWindow: NSWindow? {
        statusItem.isVisible ? statusItem.button?.window : nil
    }

    func update(state: AppState, settings: MonitoredApp, config: Config) {
        self.state = state
        self.settings = settings
        self.config = config
        if statusItem.isVisible {
            position.recordIfMissing(itemWindow: statusItem.button?.window)
        }
        redraw()
    }

    #if DEBUG
    var debugItem: DebugState.Item {
        DebugState.Item(
            bundleID: state.bundleID,
            badge: state.badge,
            isDockItemFound: state.isDockItemFound,
            isVisible: statusItem.isVisible,
            frame: itemWindow.map { DebugState.Rect($0.frame) },
            title: statusItem.button?.title ?? "",
            redBadgeLabel: appearance?.face.redBadgeLabel,
            iconMode: settings.icon.rawValue,
            redrawCount: redrawCount
        )
    }
    #endif

    func remove() {
        for observer in [backingObserver, defaultsObserver].compactMap(\.self) {
            NotificationCenter.default.removeObserver(observer)
        }
        NSStatusBar.system.removeStatusItem(statusItem)
        position.forget()
    }

    private func setUpButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(buttonClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        face.install(in: button)
        backingObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeBackingPropertiesNotification, object: nil, queue: .main
        ) { [weak self] note in
            let window = note.object as? NSWindow
            MainActor.assumeIsolated {
                guard let self, window === self.statusItem.button?.window else { return }
                self.redraw()
            }
        }
        // macOS writes the new position into our defaults after a Command-drag.
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.statusItem.isVisible else { return }
                self.position.backUp()
            }
        }
    }

    private func redraw() {
        let next = makeAppearance()
        guard next != appearance else { return }
        appearance = next
        #if DEBUG
        redrawCount += 1
        #endif
        guard let button = statusItem.button else { return }

        face.draw(next.face, in: button)
        button.appearsDisabled = next.isDimmed
        button.toolTip = next.toolTip
        button.setAccessibilityLabel(next.accessibilityLabel)
        setVisible(next.isVisible)
    }

    private func setVisible(_ isVisible: Bool) {
        guard statusItem.isVisible != isVisible else { return }
        if isVisible { position.restore() } else { position.backUp() }
        statusItem.isVisible = isVisible
    }

    private func makeAppearance() -> Appearance {
        let badge = state.badge
        let isNothingNew = badge.isEmpty
        let isHidden = ItemVisibility.isHidden(badge: badge, isRunning: state.isRunning, config: config)
        let isDimmed = config.whenNothingNew == .dim && isNothingNew
        let scale = statusItem.button?.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        return Appearance(
            isVisible: !isHidden,
            face: ItemFace.Look(
                badge: badge,
                style: config.badgeStyle,
                icon: ItemIcons.Source(appURL: state.appURL, mode: settings.icon, scale: scale),
                variant: isDimmed ? .dimmed : .plain
            ),
            isDimmed: isDimmed,
            toolTip: state.isInstalled ? nil : String(localized: "\(state.bundleID) is not installed. Click for options."),
            accessibilityLabel: isNothingNew
                ? String(localized: "\(state.name), nothing new")
                : String(localized: "\(state.name), \(badge) new")
        )
    }

    @objc private func buttonClicked() {
        onClick(state.bundleID)
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showMenu()
        } else if state.isInstalled {
            AppActivation.toggle(bundleID: state.bundleID, appURL: state.appURL)
        } else {
            openSettings(.apps(selecting: state.bundleID))
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let open = menu.addItem(withTitle: String(localized: "Open \(state.name)"), action: #selector(openApp), keyEquivalent: "")
        open.isEnabled = state.isInstalled
        menu.addItem(withTitle: String(localized: "\(state.name) Options…"), action: #selector(openAppOptions), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: String(localized: "Settings…"), action: #selector(openLastSettings), keyEquivalent: "")
            .image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        menu.addItem(withTitle: String(localized: "Quit \(AppInfo.name)"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
            .target = NSApp
        for item in menu.items where item.target == nil && !item.isSeparatorItem {
            item.target = self
        }
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openApp() {
        AppActivation.open(bundleID: state.bundleID, appURL: state.appURL)
    }

    @objc private func openAppOptions() {
        openSettingsAfterMenuCloses(.apps(selecting: state.bundleID))
    }

    @objc private func openLastSettings() {
        openSettingsAfterMenuCloses(.lastTab)
    }

    /// A window that becomes key while the menu still tracks does not keep the focus. The default run loop mode
    /// runs only after the tracking ends.
    private func openSettingsAfterMenuCloses(_ request: SettingsRequest) {
        pendingSettingsRequest = request
        perform(#selector(openPendingSettings), with: nil, afterDelay: 0, inModes: [.default])
    }

    @objc private func openPendingSettings() {
        guard let request = pendingSettingsRequest else { return }
        pendingSettingsRequest = nil
        openSettings(request)
    }
}
