import AppKit

enum MainMenu {
    static func make() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(submenuItem(appMenu()))
        menu.addItem(submenuItem(editMenu()))
        menu.addItem(submenuItem(windowMenu()))
        return menu
    }

    private static func submenuItem(_ submenu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem()
        item.submenu = submenu
        return item
    }

    private static func appMenu() -> NSMenu {
        let name = AppInfo.name
        let menu = NSMenu()
        menu.addItem(item(String(localized: "About \(name)"), #selector(NSApplication.orderFrontStandardAboutPanel(_:))))
        menu.addItem(.separator())
        menu.addItem(item(String(localized: "Hide \(name)"), #selector(NSApplication.hide(_:)), "h"))
        menu.addItem(.separator())
        menu.addItem(item(String(localized: "Quit \(name)"), #selector(NSApplication.terminate(_:)), "q"))
        return menu
    }

    private static func editMenu() -> NSMenu {
        let menu = NSMenu(title: String(localized: "Edit"))
        menu.addItem(item(String(localized: "Undo"), Selector(("undo:")), "z"))
        let redo = item(String(localized: "Redo"), Selector(("redo:")), "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(redo)
        menu.addItem(.separator())
        menu.addItem(item(String(localized: "Cut"), #selector(NSText.cut(_:)), "x"))
        menu.addItem(item(String(localized: "Copy"), #selector(NSText.copy(_:)), "c"))
        menu.addItem(item(String(localized: "Paste"), #selector(NSText.paste(_:)), "v"))
        menu.addItem(item(String(localized: "Select All"), #selector(NSText.selectAll(_:)), "a"))
        return menu
    }

    private static func windowMenu() -> NSMenu {
        let menu = NSMenu(title: String(localized: "Window"))
        menu.addItem(item(String(localized: "Minimize"), #selector(NSWindow.performMiniaturize(_:)), "m"))
        menu.addItem(item(String(localized: "Zoom"), #selector(NSWindow.performZoom(_:))))
        menu.addItem(.separator())
        menu.addItem(item(String(localized: "Close"), #selector(NSWindow.performClose(_:)), "w"))
        return menu
    }

    private static func item(_ title: String, _ action: Selector, _ key: String = "") -> NSMenuItem {
        NSMenuItem(title: title, action: action, keyEquivalent: key)
    }
}
