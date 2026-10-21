import Testing
@testable import BadgerCore

struct BadgeRulesTests {
    /// Stands in for the measured capsule width: three characters fit the icon.
    private static func fitsThreeCharacters(_ text: String) -> Bool { text.count <= 3 }

    @Test(arguments: ["100", "123", "999+", "1,234", "1 234", "1\u{00A0}234", "1\u{202F}234", "1'234", "12345678901234567890"])
    func countAbove99GivesOverflow(badge: String) {
        #expect(RedBadgeLabel.label(for: badge, fits: Self.fitsThreeCharacters) == "99+")
    }

    @Test(arguments: ["1", "99", "007", "9+", "99+", "1.5", "new", "•••"])
    func fittingTextShowsAsItIs(badge: String) {
        #expect(RedBadgeLabel.label(for: badge, fits: Self.fitsThreeCharacters) == badge)
    }

    @Test(arguments: ["hello", "1a2b", "+1234", ",1234"])
    func otherTextGivesADot(badge: String) {
        #expect(RedBadgeLabel.label(for: badge, fits: Self.fitsThreeCharacters) == "•")
    }

    @Test func countParser() {
        #expect(BadgeCount.parse("1,234") == 1234)
        #expect(BadgeCount.parse("99+") == 99)
        #expect(BadgeCount.parse("007") == 7)
        #expect(BadgeCount.parse("12345678901234567890") == .max)
        #expect(BadgeCount.parse("•") == nil)
        #expect(BadgeCount.parse("") == nil)
        #expect(BadgeCount.parse("+1") == nil)
        #expect(BadgeCount.parse("1a") == nil)
    }

    @Test func displayNameDropsOneTrailingDotApp() {
        #expect(DisplayName.fromBundleName("My.app Tools.app") == "My.app Tools")
        #expect(DisplayName.fromBundleName("Mail") == "Mail")
        #expect(DisplayName.fromBundleName("Twice.app.app") == "Twice.app")
    }
}
