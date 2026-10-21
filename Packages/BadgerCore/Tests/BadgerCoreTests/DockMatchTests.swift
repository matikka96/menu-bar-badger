import Testing
@testable import BadgerCore

struct DockMatchTests {
    @Test func bundleIDWinsOverAnEarlierItemWithTheSameTitle() {
        let items = [
            DockItemDescription(bundleID: "com.other.teams", title: "Teams"),
            DockItemDescription(bundleID: nil, title: "Teams"),
            DockItemDescription(bundleID: "com.microsoft.teams2", title: "Microsoft Teams"),
        ]
        #expect(DockMatch.index(forBundleID: "com.microsoft.teams2", displayName: "Teams", in: items) == 2)
    }

    @Test func titleMatchesOnlyAnItemWithNoBundleID() {
        let items = [
            DockItemDescription(bundleID: "com.other.teams", title: "Teams"),
            DockItemDescription(bundleID: nil, title: "Teams"),
        ]
        #expect(DockMatch.index(forBundleID: "com.microsoft.teams2", displayName: "Teams", in: items) == 1)
    }

    @Test func anotherBundleIDNeverMatches() {
        let items = [DockItemDescription(bundleID: "com.other.outlook", title: "Outlook")]
        #expect(DockMatch.index(forBundleID: "com.microsoft.Outlook", displayName: "Outlook", in: items) == nil)
    }
}
