import Foundation

/// One badge change of one monitored app, with the state after the change.
public struct BadgeChange: Sendable, Equatable {
    public var oldBadge: String
    public var newBadge: String
    public var badgeStyle: BadgeStyle
    public var isAppActive: Bool
    public var isItemHidden: Bool

    public init(oldBadge: String, newBadge: String, badgeStyle: BadgeStyle, isAppActive: Bool, isItemHidden: Bool) {
        self.oldBadge = oldBadge
        self.newBadge = newBadge
        self.badgeStyle = badgeStyle
        self.isAppActive = isAppActive
        self.isItemHidden = isItemHidden
    }
}

public enum AttentionRules {
    public static func hidesAlertAndArrow(badge: String, isItemHidden: Bool, didAppBecomeActive: Bool) -> Bool {
        badge.isEmpty || isItemHidden || didAppBecomeActive
    }

    public static func allowsArrow(isArrowOn: Bool, badgeStyle: BadgeStyle) -> Bool {
        isArrowOn && badgeStyle != .iconOnly
    }

    /// The rules that do not need the menu bar check. When this is false, the alert does not show.
    public static func canShowAlert(for change: BadgeChange, isAlertOn: Bool) -> Bool {
        isAlertOn && change.badgeStyle != .iconOnly && !change.newBadge.isEmpty && !change.isItemHidden
    }

    public static func showsAlert(for change: BadgeChange, isAlertOn: Bool, isMenuBarHidden: Bool) -> Bool {
        canShowAlert(for: change, isAlertOn: isAlertOn) && isMenuBarHidden
    }

    /// The rules that do not need the menu bar check. When this is false, the arrow hides.
    public static func canShowArrow(for change: BadgeChange, isArrowOn: Bool) -> Bool {
        allowsArrow(isArrowOn: isArrowOn, badgeStyle: change.badgeStyle) && !change.isAppActive && !change.newBadge.isEmpty
            && !isLower(change.newBadge, than: change.oldBadge) && !change.isItemHidden
    }

    public static func showsArrow(for change: BadgeChange, isArrowOn: Bool, isMenuBarHidden: Bool) -> Bool {
        canShowArrow(for: change, isArrowOn: isArrowOn) && !isMenuBarHidden
    }

    private static func isLower(_ new: String, than old: String) -> Bool {
        guard let new = BadgeCount.parse(new), let old = BadgeCount.parse(old) else { return false }
        return new < old
    }
}
