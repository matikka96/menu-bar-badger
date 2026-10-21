import AppKit
import BadgerCore

final class StatusItemController: NSObject {
    private struct Appearance: Equatable {
        var isVisible: Bool
        var icon: ItemIcons.Source
        var variant: ItemIcons.Variant
        var isDimmed: Bool
        var title: String
        var redBadgeLabel: String?
        var toolTip: String?
        var accessibilityLabel: String
    }

    private let statusItem: NSStatusItem
    private let position: ItemPosition
    private let icons = ItemIcons()
    private let redBadge = RedBadgeView()
    private let openSettings: (SettingsRequest) -> Void
    private var state: AppState
    private var settings: MonitoredApp
    private var config: Config
    private var appearance: Appearance?
    private var backingObserver: NSObjectProtocol?
    private var defaultsObserver: NSObjectProtocol?

    init(state: AppState, settings: MonitoredApp, config: Config, openSettings: @escaping (SettingsRequest) -> Void) {
        self.state = state
        self.settings = settings
        self.config = config
        self.openSettings = openSettings
        position = ItemPosition(bundleID: state.bundleID)
        position.restore()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = position.autosaveName
        super.init()
        setUpButton()
        redraw()
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
        button.font = .monospacedDigitSystemFont(ofSize: NSFont.menuBarFont(ofSize: 0).pointSize, weight: .regular)
        button.addSubview(redBadge)
        let corner = ItemIcons.size / 2
        NSLayoutConstraint.activate([
            redBadge.trailingAnchor.constraint(equalTo: button.centerXAnchor, constant: corner),
            redBadge.topAnchor.constraint(equalTo: button.centerYAnchor, constant: -corner),
        ])
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
        guard let button = statusItem.button else { return }

        button.image = icons.image(next.variant, for: next.icon)
        button.appearsDisabled = next.isDimmed
        button.title = next.title
        button.imagePosition = next.title.isEmpty ? .imageOnly : .imageLeading
        redBadge.text = next.redBadgeLabel ?? ""
        redBadge.isHidden = next.redBadgeLabel == nil
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
        let isHidden = (config.whenNothingNew == .hide && isNothingNew) || (config.hideWhenNotRunning && !state.isRunning)
        let isDimmed = config.whenNothingNew == .dim && isNothingNew
        let redBadgeLabel = config.badgeStyle == .redBadge && !isNothingNew
            ? RedBadgeLabel.label(for: badge, fits: RedBadgeView.fits)
            : nil
        let scale = statusItem.button?.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        return Appearance(
            isVisible: !isHidden,
            icon: ItemIcons.Source(appURL: state.appURL, mode: settings.icon, scale: scale),
            variant: isDimmed ? .dimmed : redBadgeLabel == nil ? .plain : .shrunk,
            isDimmed: isDimmed,
            title: config.badgeStyle == .number ? badge : "",
            redBadgeLabel: redBadgeLabel,
            toolTip: state.isInstalled ? nil : String(localized: "\(state.bundleID) is not installed. Click for options."),
            accessibilityLabel: isNothingNew
                ? String(localized: "\(state.name), nothing new")
                : String(localized: "\(state.name), \(badge) new")
        )
    }

    @objc private func buttonClicked() {
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
        openSettings(.apps(selecting: state.bundleID))
    }

    @objc private func openLastSettings() {
        openSettings(.lastTab)
    }
}
