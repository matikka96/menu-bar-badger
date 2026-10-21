import Foundation
import Testing
@testable import BadgerCore

private final class FakeItem {
    var badge: String
    var isStale = false

    init(_ badge: String) { self.badge = badge }
}

private final class FakeDock: DockSource, @unchecked Sendable {
    var processID: Int32 = 1
    var entries: [(item: FakeItem, description: DockItemDescription)] = []

    func isTrusted() -> Bool { true }
    func dockProcessID() -> Int32? { processID }
    func observe(processID: Int32, onEvent: @escaping @Sendable (DockEvent) -> Void) -> Bool { true }
    func items() -> [(item: FakeItem, description: DockItemDescription)] { entries }

    func badge(of item: FakeItem) throws(StaleDockItem) -> String {
        guard !item.isStale else { throw StaleDockItem() }
        return item.badge
    }

    @discardableResult
    func add(_ bundleID: String, badge: String) -> FakeItem {
        let item = FakeItem(badge)
        entries.append((item, DockItemDescription(bundleID: bundleID, title: nil)))
        return item
    }
}

struct DockReaderTests {
    private let mail = MonitoredDockApp(bundleID: "com.apple.mail", displayName: "Mail")

    private func makeReader(_ dock: FakeDock) async -> DockReader<FakeDock> {
        let reader = DockReader(source: dock)
        await reader.setApps([mail])
        return reader
    }

    @Test func staleItemIsReplacedInTheSamePoll() async {
        let dock = FakeDock()
        let old = dock.add(mail.bundleID, badge: "1")
        let reader = await makeReader(dock)
        #expect(await reader.poll() == [mail.bundleID: DockAppState(badge: "1", isDockItemFound: true)])

        old.isStale = true
        dock.entries = []
        dock.add(mail.bundleID, badge: "2")
        #expect(await reader.poll() == [mail.bundleID: DockAppState(badge: "2", isDockItemFound: true)])
    }

    @Test func staleItemWithNoReplacementGivesAnEmptyBadge() async {
        let dock = FakeDock()
        let old = dock.add(mail.bundleID, badge: "1")
        dock.add("com.apple.finder", badge: "")
        let reader = await makeReader(dock)
        await reader.poll()

        old.isStale = true
        dock.entries.removeFirst()
        #expect(await reader.poll() == [mail.bundleID: .absent])
    }

    @Test func dockWithZeroItemsKeepsTheOldItemsAndRecovers() async {
        let dock = FakeDock()
        let old = dock.add(mail.bundleID, badge: "1")
        let reader = await makeReader(dock)
        await reader.poll()

        old.isStale = true
        dock.processID = 2
        dock.entries = []
        #expect(await reader.poll() == [:])
        #expect(await reader.poll() == [:])

        dock.add(mail.bundleID, badge: "3")
        #expect(await reader.poll() == [mail.bundleID: DockAppState(badge: "3", isDockItemFound: true)])
    }

    @Test func dockRestartFindsTheNewItems() async {
        let dock = FakeDock()
        dock.add(mail.bundleID, badge: "1")
        let reader = await makeReader(dock)
        await reader.poll()

        dock.processID = 2
        dock.entries = []
        dock.add(mail.bundleID, badge: "4")
        #expect(await reader.poll() == [mail.bundleID: DockAppState(badge: "4", isDockItemFound: true)])
    }

    @Test func unchangedBadgeSendsNothing() async {
        let dock = FakeDock()
        dock.add(mail.bundleID, badge: "1")
        let reader = await makeReader(dock)
        await reader.poll()
        #expect(await reader.poll() == [:])
    }
}
