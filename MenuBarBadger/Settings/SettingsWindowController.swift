import AppKit
import BadgerCore
import OSLog
import SwiftUI

enum SettingsRequest: Equatable {
    case lastTab
    case apps(selecting: String?)
    case addApp
}

final class SettingsWindowController: NSWindowController, NSToolbarDelegate {
    private enum Tab: Int {
        case apps
        case general
    }

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MenuBarBadger", category: "settings")
    private static let frameName = "Settings"
    private static let lastTabKey = "SettingsLastTab"
    private static let tabPickerItem = NSToolbarItem.Identifier("tabs")
    private static let toolbarItems: [NSToolbarItem.Identifier] = [.flexibleSpace, tabPickerItem, .flexibleSpace]

    private let model: AppModel
    private let tabs = SettingsTabViewController()
    private let tabPicker = NSSegmentedControl()
    /// The setup screen is a tab with no segment in the tab picker. The picker shows only after Done.
    private var setupTab: NSTabViewItem?
    /// An open before the first permission check waits for it, so that the window never shows a wrong state.
    private var requestBeforePermission: SettingsRequest?

    init(model: AppModel) {
        self.model = model
        let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: true)
        super.init(window: window)

        tabs.tabStyle = .unspecified
        tabs.addTabViewItem(Self.tabItem(
            title: String(localized: "Apps"), root: AppsTab(model: model)
        ))
        tabs.addTabViewItem(Self.tabItem(
            title: String(localized: "General"), root: GeneralTab(model: model)
        ))
        let lastTab = Tab(rawValue: UserDefaults.standard.integer(forKey: Self.lastTabKey)) ?? .apps
        tabs.selectedTabViewItemIndex = lastTab.rawValue
        tabs.onSelect = { [tabPicker] index in
            guard Tab(rawValue: index) != nil else { return }
            tabPicker.selectedSegment = index
            UserDefaults.standard.set(index, forKey: Self.lastTabKey)
        }

        tabPicker.segmentCount = tabs.tabViewItems.count
        for (index, item) in tabs.tabViewItems.enumerated() {
            tabPicker.setLabel(item.label, forSegment: index)
        }
        tabPicker.trackingMode = .selectOne
        tabPicker.selectedSegment = lastTab.rawValue
        tabPicker.target = self
        tabPicker.action = #selector(selectTab(_:))
        tabPicker.setAccessibilityIdentifier("settingsTabs")

        let toolbar = NSToolbar(identifier: "Settings")
        toolbar.delegate = self
        toolbar.allowsUserCustomization = false
        toolbar.displayMode = .iconOnly
        toolbar.allowsDisplayModeCustomization = false
        toolbar.centeredItemIdentifiers = [Self.tabPickerItem]

        if model.isSetupPending {
            let setupTab = Self.tabItem(
                title: String(localized: "Setup"), root: SetupScreen(model: model) { [weak self] in self?.finishSetup() }
            )
            tabs.addTabViewItem(setupTab)
            tabs.selectedTabViewItemIndex = tabs.tabViewItems.count - 1
            self.setupTab = setupTab
        }

        window.contentViewController = tabs
        window.title = AppInfo.name
        window.toolbar = toolbar
        window.toolbarStyle = .unified
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        let hasSavedFrame = window.setFrameUsingName(Self.frameName)
        window.setFrameAutosaveName(Self.frameName)
        tabs.fitWindowToSelectedTab(animated: false)
        if !hasSavedFrame {
            window.center()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not available")
    }

    func open(_ request: SettingsRequest) {
        guard let window else { return }
        guard model.isTrusted != nil else {
            requestBeforePermission = request
            return
        }
        Self.log.info("Settings window opens: \(String(describing: request))")
        let wasVisible = window.isVisible
        if !wasVisible {
            model.refreshInstalledApps()
            model.catalog.refresh()
            model.refreshLoginItemStatus()
        }
        switch setupTab == nil ? request : .lastTab {
        case .lastTab:
            break
        case .apps(let bundleID):
            tabs.selectedTabViewItemIndex = Tab.apps.rawValue
            if let bundleID {
                model.selectedBundleID = bundleID
            }
        case .addApp:
            tabs.selectedTabViewItemIndex = Tab.apps.rawValue
            model.isAddSheetPresented = true
        }
        // macOS does not activate an agent app at launch, and `activate()` waits for the frontmost app to yield,
        // which it never does. Each open comes from the user, so the window takes the focus.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        if !wasVisible {
            tabs.stopShortcutRecording()
        }
    }

    func permissionCheckDidEnd() {
        guard let request = requestBeforePermission else { return }
        requestBeforePermission = nil
        open(request)
    }

    private func finishSetup() {
        guard let setupTab, let toolbar = window?.toolbar else { return }
        model.finishSetup()
        self.setupTab = nil
        for (index, identifier) in toolbarDefaultItemIdentifiers(toolbar).enumerated() {
            toolbar.insertItem(withItemIdentifier: identifier, at: index)
        }
        open(model.config.apps.isEmpty ? .addApp : .apps(selecting: nil))
        tabs.removeTabViewItem(setupTab)
    }

    @objc private func selectTab(_ sender: NSSegmentedControl) {
        tabs.selectedTabViewItemIndex = sender.selectedSegment
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        setupTab == nil ? Self.toolbarItems : []
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        Self.toolbarItems
    }

    func toolbar(
        _ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        guard identifier == Self.tabPickerItem else { return nil }
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.view = tabPicker
        return item
    }

    private static func tabItem(title: String, root: some View) -> NSTabViewItem {
        let controller = NSHostingController(rootView: root)
        controller.sizingOptions = .preferredContentSize
        controller.title = title
        let item = NSTabViewItem(viewController: controller)
        item.label = title
        return item
    }
}

/// Fits the window height to the selected tab and keeps the top edge in place.
private final class SettingsTabViewController: NSTabViewController {
    var onSelect: ((Int) -> Void)?

    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        fitWindowToSelectedTab(animated: view.window?.isVisible == true)
        onSelect?(selectedTabViewItemIndex)
        DispatchQueue.main.async { [weak self] in
            self?.stopShortcutRecording()
        }
    }

    /// The shortcut recorder is the only text field in the tabs. It records the next key press while it has the
    /// focus, so it must not get the focus from a tab change.
    func stopShortcutRecording() {
        guard let window = view.window, window.firstResponder is NSTextView else { return }
        window.makeFirstResponder(nil)
    }

    override func preferredContentSizeDidChange(for viewController: NSViewController) {
        super.preferredContentSizeDidChange(for: viewController)
        guard viewController === tabViewItems[selectedTabViewItemIndex].viewController else { return }
        fitWindowToSelectedTab(animated: view.window?.isVisible == true)
    }

    func fitWindowToSelectedTab(animated: Bool) {
        guard let window = view.window,
              let size = tabViewItems[selectedTabViewItemIndex].viewController?.preferredContentSize,
              size.width > 0, size.height > 0
        else { return }
        let content = window.contentRect(forFrameRect: window.frame)
        var frame = window.frameRect(forContentRect: NSRect(origin: content.origin, size: size))
        frame.origin.y = window.frame.maxY - frame.height
        guard frame != window.frame else { return }
        window.setFrame(frame, display: true, animate: animated)
    }
}
