import Foundation

public enum IconMode: String, Sendable, Equatable, CaseIterable {
    case color
    case monochrome
}

public enum BadgeStyle: String, Sendable, Equatable, CaseIterable {
    case number
    case redBadge
    case iconOnly
}

public enum NothingNewMode: String, Sendable, Equatable, CaseIterable {
    case show
    case dim
    case hide
}

public struct MonitoredApp: Sendable, Equatable {
    public var bundleID: String
    public var name: String?
    public var icon: IconMode
    public var arrow: Bool

    public init(bundleID: String, name: String? = nil, icon: IconMode = .color, arrow: Bool = false) {
        self.bundleID = bundleID
        self.name = name
        self.icon = icon
        self.arrow = arrow
    }
}

public struct Config: Sendable, Equatable {
    public static let currentVersion = 1

    public var apps: [MonitoredApp]
    public var badgeStyle: BadgeStyle
    public var whenNothingNew: NothingNewMode
    public var hideWhenNotRunning: Bool
    public var alertWhenMenuBarHidden: Bool
    public var openSettingsShortcut: Shortcut?

    public init(
        apps: [MonitoredApp] = [],
        badgeStyle: BadgeStyle = .number,
        whenNothingNew: NothingNewMode = .show,
        hideWhenNotRunning: Bool = false,
        alertWhenMenuBarHidden: Bool = true,
        openSettingsShortcut: Shortcut? = nil
    ) {
        self.apps = apps
        self.badgeStyle = badgeStyle
        self.whenNothingNew = whenNothingNew
        self.hideWhenNotRunning = hideWhenNotRunning
        self.alertWhenMenuBarHidden = alertWhenMenuBarHidden
        self.openSettingsShortcut = openSettingsShortcut
    }
}
