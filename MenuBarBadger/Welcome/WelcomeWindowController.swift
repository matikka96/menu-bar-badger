import AppKit
import SwiftUI

final class WelcomeWindowController {
    private let model: AppModel
    private let openSettings: (SettingsRequest) -> Void
    private var window: NSWindow?

    init(model: AppModel, openSettings: @escaping (SettingsRequest) -> Void) {
        self.model = model
        self.openSettings = openSettings
    }

    var isVisible: Bool { window?.isVisible == true }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        center(window)
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let view = WelcomeView(model: model) { [weak self] in self?.addApps() }
        let controller = NSHostingController(rootView: view)
        controller.sizingOptions = .preferredContentSize
        let window = NSWindow(contentViewController: controller)
        window.styleMask = [.titled, .closable]
        window.title = AppInfo.name
        window.isReleasedWhenClosed = false
        return window
    }

    private func center(_ window: NSWindow) {
        let pointer = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }) ?? NSScreen.main else { return }
        let size = window.frame.size
        let visible = screen.visibleFrame
        window.setFrameOrigin(NSPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2))
    }

    private func addApps() {
        window?.close()
        openSettings(.addApp)
    }
}
