import Testing
@testable import BadgerCore

struct AttentionRulesTests {
    private static func change(
        _ oldBadge: String, _ newBadge: String,
        style: BadgeStyle = .number, isAppActive: Bool = false, isItemHidden: Bool = false
    ) -> BadgeChange {
        BadgeChange(oldBadge: oldBadge, newBadge: newBadge, badgeStyle: style, isAppActive: isAppActive, isItemHidden: isItemHidden)
    }

    @Test func alertShowsOnlyForANewBadgeOfAVisibleItemWhenTheMenuBarIsHidden() {
        #expect(AttentionRules.showsAlert(for: Self.change("", "3"), isAlertOn: true, isMenuBarHidden: true))
        #expect(AttentionRules.showsAlert(for: Self.change("5", "3", style: .redBadge, isAppActive: true), isAlertOn: true, isMenuBarHidden: true))
        #expect(!AttentionRules.showsAlert(for: Self.change("", "3"), isAlertOn: true, isMenuBarHidden: false))
        #expect(!AttentionRules.showsAlert(for: Self.change("", "3"), isAlertOn: false, isMenuBarHidden: true))
        #expect(!AttentionRules.showsAlert(for: Self.change("", "3", style: .iconOnly), isAlertOn: true, isMenuBarHidden: true))
        #expect(!AttentionRules.showsAlert(for: Self.change("3", ""), isAlertOn: true, isMenuBarHidden: true))
        #expect(!AttentionRules.showsAlert(for: Self.change("", "3", isItemHidden: true), isAlertOn: true, isMenuBarHidden: true))
    }

    @Test func arrowComparesCounts() {
        #expect(AttentionRules.showsArrow(for: Self.change("", "1"), isArrowOn: true, isMenuBarHidden: false))
        #expect(AttentionRules.showsArrow(for: Self.change("2", "3"), isArrowOn: true, isMenuBarHidden: false))
        #expect(AttentionRules.showsArrow(for: Self.change("1,234", "1,235"), isArrowOn: true, isMenuBarHidden: false))
        #expect(AttentionRules.showsArrow(for: Self.change("99+", "100"), isArrowOn: true, isMenuBarHidden: false))
        #expect(!AttentionRules.showsArrow(for: Self.change("5", "3"), isArrowOn: true, isMenuBarHidden: false))
        #expect(!AttentionRules.showsArrow(for: Self.change("1,234", "999"), isArrowOn: true, isMenuBarHidden: false))
    }

    @Test func arrowTakesAnyChangeWithANonCountBadge() {
        #expect(AttentionRules.showsArrow(for: Self.change("5", "•"), isArrowOn: true, isMenuBarHidden: false))
        #expect(AttentionRules.showsArrow(for: Self.change("•", "1"), isArrowOn: true, isMenuBarHidden: false))
        #expect(AttentionRules.showsArrow(for: Self.change("new", "•"), isArrowOn: true, isMenuBarHidden: false))
    }

    @Test func arrowDoesNotShowForTheActiveAppOrAHiddenMenuBar() {
        #expect(!AttentionRules.showsArrow(for: Self.change("", "1", isAppActive: true), isArrowOn: true, isMenuBarHidden: false))
        #expect(!AttentionRules.showsArrow(for: Self.change("", "1"), isArrowOn: true, isMenuBarHidden: true))
        #expect(AttentionRules.canShowArrow(for: Self.change("", "1"), isArrowOn: true))
    }

    @Test func arrowDoesNotShowWhenOffClearedHiddenOrIconOnly() {
        #expect(!AttentionRules.showsArrow(for: Self.change("", "1"), isArrowOn: false, isMenuBarHidden: false))
        #expect(!AttentionRules.showsArrow(for: Self.change("1", ""), isArrowOn: true, isMenuBarHidden: false))
        #expect(!AttentionRules.showsArrow(for: Self.change("", "1", isItemHidden: true), isArrowOn: true, isMenuBarHidden: false))
        #expect(!AttentionRules.showsArrow(for: Self.change("", "1", style: .iconOnly), isArrowOn: true, isMenuBarHidden: false))
    }

    @Test func bothGoAwayWhenTheBadgeClearsTheItemHidesOrTheAppBecomesActive() {
        #expect(!AttentionRules.hidesAlertAndArrow(badge: "1", isItemHidden: false, didAppBecomeActive: false))
        #expect(AttentionRules.hidesAlertAndArrow(badge: "", isItemHidden: false, didAppBecomeActive: false))
        #expect(AttentionRules.hidesAlertAndArrow(badge: "1", isItemHidden: true, didAppBecomeActive: false))
        #expect(AttentionRules.hidesAlertAndArrow(badge: "1", isItemHidden: false, didAppBecomeActive: true))
    }

    @Test func arrowGoesAwayWhenTurnedOffOrIconOnly() {
        #expect(AttentionRules.allowsArrow(isArrowOn: true, badgeStyle: .redBadge))
        #expect(!AttentionRules.allowsArrow(isArrowOn: false, badgeStyle: .number))
        #expect(!AttentionRules.allowsArrow(isArrowOn: true, badgeStyle: .iconOnly))
    }
}
