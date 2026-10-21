import AppKit
import BadgerCore
import Observation

final class AttentionController {
    private struct Input: Sendable, Equatable {
        var apps: [AppState]
        var config: Config
    }

    private static let alertLifetime: Duration = .seconds(3)
    private static let settleTime: Duration = .milliseconds(100)
    private static let maxSettleWait: Duration = .milliseconds(500)
    private static let settleSampleInterval: Duration = .milliseconds(20)
    /// A window that goes full screen reports it some 0.2 to 0.6 s after the Space change.
    private static let menuBarCheckWait: Duration = .milliseconds(1500)
    private static let menuBarCheckInterval: Duration = .milliseconds(250)

    private let model: AppModel
    private var itemWindow: (String) -> NSWindow? = { _ in nil }
    private var lastStates: [String: AppState] = [:]
    private var alerts: [String: AlertPanel] = [:]
    private var arrows: [String: ArrowPanel] = [:]
    private var pendingShows: [String: Task<Void, Never>] = [:]
    private var alertTimeouts: [String: Task<Void, Never>] = [:]
    private var menuBarChecks: [String: Task<Void, Never>] = [:]
    private var observation: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []

    init(model: AppModel) {
        self.model = model
    }

    func start(itemWindow: @escaping (String) -> NSWindow?) {
        self.itemWindow = itemWindow
        lastStates = Dictionary(uniqueKeysWithValues: model.apps.map { ($0.bundleID, $0) })
        let model = model
        observation = Task { [weak self] in
            for await _ in Observations({ Input(apps: model.apps, config: model.config) }) {
                self?.sync()
            }
        }
        followItemMoves()
        observeMenuBarChanges()
    }

    func dismiss(bundleID: String) {
        pendingShows.removeValue(forKey: bundleID)?.cancel()
        hideAlert(of: bundleID)
        hideArrow(of: bundleID)
    }

    private func sync() {
        let monitored = Set(model.apps.map(\.bundleID))
        for bundleID in lastStates.keys where !monitored.contains(bundleID) {
            dismiss(bundleID: bundleID)
            lastStates[bundleID] = nil
        }
        for app in model.apps {
            guard let settings = model.settings(of: app.bundleID) else { continue }
            let old = lastStates[app.bundleID]
            lastStates[app.bundleID] = app
            let isItemHidden = ItemVisibility.isHidden(badge: app.badge, isRunning: app.isRunning, config: model.config)
            let didAppBecomeActive = app.isActive && old?.isActive == false
            if AttentionRules.hidesAlertAndArrow(badge: app.badge, isItemHidden: isItemHidden, didAppBecomeActive: didAppBecomeActive) {
                dismiss(bundleID: app.bundleID)
                continue
            }
            if !AttentionRules.allowsArrow(isArrowOn: settings.arrow, badgeStyle: model.config.badgeStyle) {
                hideArrow(of: app.bundleID)
            }
            guard let old, old.badge != app.badge else { continue }
            let change = BadgeChange(
                oldBadge: old.badge, newBadge: app.badge, badgeStyle: model.config.badgeStyle,
                isAppActive: app.isActive, isItemHidden: isItemHidden
            )
            handle(change, of: app.bundleID, isArrowOn: settings.arrow)
        }
    }

    private func handle(_ change: BadgeChange, of bundleID: String, isArrowOn: Bool) {
        let canShowAlert = AttentionRules.canShowAlert(for: change, isAlertOn: model.config.alertWhenMenuBarHidden)
        let canShowArrow = AttentionRules.canShowArrow(for: change, isArrowOn: isArrowOn)
        if !canShowArrow {
            hideArrow(of: bundleID)
        }
        pendingShows.removeValue(forKey: bundleID)?.cancel()
        guard canShowAlert || canShowArrow else { return }
        pendingShows[bundleID] = Task { [weak self] in
            guard await self?.settledItemWindow(of: bundleID) != nil,
                  let screen = self?.itemPlace(of: bundleID)?.screen
            else { return }
            let isMenuBarHidden = await MenuBarCheck.isMenuBarHidden(on: screen)
            guard !Task.isCancelled, let self else { return }
            pendingShows[bundleID] = nil
            // The config can change during the wait.
            var change = change
            change.badgeStyle = model.config.badgeStyle
            let isArrowOn = model.settings(of: bundleID)?.arrow == true
            if AttentionRules.showsAlert(for: change, isAlertOn: model.config.alertWhenMenuBarHidden, isMenuBarHidden: isMenuBarHidden) {
                showAlert(of: bundleID)
            }
            if AttentionRules.showsArrow(for: change, isArrowOn: isArrowOn, isMenuBarHidden: isMenuBarHidden) {
                showArrow(of: bundleID)
            } else {
                hideArrow(of: bundleID)
            }
        }
    }

    /// The menu bar shows an item that comes back from hidden, and moves an item that grows, some time after the
    /// change. Nil when the show is cancelled or the item stays hidden.
    private func settledItemWindow(of bundleID: String) async -> NSWindow? {
        let clock = ContinuousClock()
        let deadline = clock.now + Self.maxSettleWait
        var frame = itemWindow(bundleID)?.frame
        var stableSince = clock.now
        while clock.now < deadline, frame == nil || clock.now - stableSince < Self.settleTime {
            try? await Task.sleep(for: Self.settleSampleInterval)
            guard !Task.isCancelled else { return nil }
            let next = itemWindow(bundleID)?.frame
            if next != frame {
                frame = next
                stableSince = clock.now
            }
        }
        return Task.isCancelled ? nil : itemWindow(bundleID)
    }

    private func showAlert(of bundleID: String) {
        guard let app = lastStates[bundleID], let settings = model.settings(of: bundleID) else { return }
        let alert = alerts[bundleID] ?? makeAlert(of: bundleID)
        alerts[bundleID] = alert
        alert.update(state: app, iconMode: settings.icon)
        guard place(alert, of: bundleID, isAnimated: alert.isShown) else { return }
        alert.show(fadeDuration: AlertPanel.fadeDuration)
        alertTimeouts[bundleID]?.cancel()
        alertTimeouts[bundleID] = Task { [weak self] in
            try? await Task.sleep(for: Self.alertLifetime)
            guard !Task.isCancelled else { return }
            self?.hideAlert(of: bundleID)
        }
    }

    private func makeAlert(of bundleID: String) -> AlertPanel {
        AlertPanel { [weak self] in
            guard let self else { return }
            dismiss(bundleID: bundleID)
            guard let app = lastStates[bundleID], app.isInstalled else { return }
            AppActivation.open(bundleID: bundleID, appURL: app.appURL)
        }
    }

    private func hideAlert(of bundleID: String) {
        alertTimeouts.removeValue(forKey: bundleID)?.cancel()
        alerts[bundleID]?.hide(fadeDuration: AlertPanel.fadeDuration)
    }

    @discardableResult
    private func place(_ alert: AlertPanel, of bundleID: String, isAnimated: Bool) -> Bool {
        guard let (itemFrame, screen) = itemPlace(of: bundleID) else { return false }
        let frame = ScreenGeometry.alertFrame(size: alert.frame.size, itemFrame: itemFrame, screenFrame: screen.frame)
        alert.move(to: frame, isAnimated: isAnimated)
        return true
    }

    private func showArrow(of bundleID: String) {
        menuBarChecks.removeValue(forKey: bundleID)?.cancel()
        let arrow = arrows[bundleID] ?? ArrowPanel()
        arrows[bundleID] = arrow
        if !arrow.isShown {
            guard place(arrow, of: bundleID) else { return }
        }
        arrow.showOrBounce()
        guard let screen = itemPlace(of: bundleID)?.screen else { return }
        hideArrowWhenMenuBarHides(of: bundleID, on: screen)
    }

    private func hideArrow(of bundleID: String) {
        menuBarChecks.removeValue(forKey: bundleID)?.cancel()
        arrows[bundleID]?.flyAway()
    }

    @discardableResult
    private func place(_ arrow: ArrowPanel, of bundleID: String, isAnimated: Bool = false) -> Bool {
        guard let (itemFrame, screen) = itemPlace(of: bundleID) else { return false }
        let menuBarBottom = min(screen.visibleFrame.maxY, itemFrame.minY)
        let frame = ScreenGeometry.arrowFrame(size: ArrowPanel.size, itemFrame: itemFrame, menuBarBottom: menuBarBottom)
        arrow.move(to: frame, isAnimated: isAnimated)
        return true
    }

    private func itemPlace(of bundleID: String) -> (itemFrame: CGRect, screen: NSScreen)? {
        guard let window = itemWindow(bundleID), let screen = MenuBarCheck.screen(ofItem: window) else { return nil }
        return (window.frame, screen)
    }

    private func followItemMoves() {
        // The menu bar resizes an item at its old origin and moves it to its final frame about 0.15 s later. Each
        // resize comes with a move, because the menu bar places the items from the right.
        observers.append(NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: nil, queue: .main) { [weak self] note in
            let window = note.object as? NSWindow
            MainActor.assumeIsolated { self?.itemDidMove(window) }
        })
    }

    private func itemDidMove(_ window: NSWindow?) {
        guard let window, model.apps.contains(where: { itemWindow($0.bundleID) === window }) else { return }
        // The menu bar can move the item for a badge change before this controller sees the change. A cleared badge
        // must hide the panels before they follow the item.
        sync()
        for (bundleID, alert) in alerts where alert.isShown && itemWindow(bundleID) === window {
            place(alert, of: bundleID, isAnimated: true)
        }
        for (bundleID, arrow) in arrows where arrow.isShown && itemWindow(bundleID) === window {
            place(arrow, of: bundleID, isAnimated: true)
        }
    }

    private func observeMenuBarChanges() {
        let workspace = NSWorkspace.shared.notificationCenter
        let app = NotificationCenter.default
        let events = [
            (workspace, NSWorkspace.activeSpaceDidChangeNotification),
            (workspace, NSWorkspace.didActivateApplicationNotification),
            (app, NSApplication.didChangeScreenParametersNotification),
        ]
        for (center, name) in events {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.hideArrowsWhereMenuBarHides() }
            })
        }
    }

    private func hideArrowsWhereMenuBarHides() {
        for (bundleID, arrow) in arrows where arrow.isShown {
            place(arrow, of: bundleID)
            guard let screen = itemPlace(of: bundleID)?.screen else { continue }
            hideArrowWhenMenuBarHides(of: bundleID, on: screen)
        }
    }

    private func hideArrowWhenMenuBarHides(of bundleID: String, on screen: NSScreen) {
        menuBarChecks[bundleID]?.cancel()
        menuBarChecks[bundleID] = Task { [weak self] in
            let deadline = ContinuousClock.now + Self.menuBarCheckWait
            repeat {
                let isMenuBarHidden = await MenuBarCheck.isMenuBarHidden(on: screen)
                guard !Task.isCancelled, let self else { return }
                if isMenuBarHidden {
                    menuBarChecks[bundleID] = nil
                    hideArrow(of: bundleID)
                    return
                }
                try? await Task.sleep(for: Self.menuBarCheckInterval)
            } while !Task.isCancelled && ContinuousClock.now < deadline
            guard !Task.isCancelled else { return }
            self?.menuBarChecks[bundleID] = nil
        }
    }
}
