#if DEBUG
import BadgerCore
import Foundation

/// Reads the badges from a JSON file of bundle ID to badge text, for tests with no Accessibility permission.
nonisolated final class FakeDockSource: DockSource {
    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func isTrusted() -> Bool { true }
    func dockProcessID() -> Int32? { 1 }
    func observe(processID: Int32, onEvent: @escaping @Sendable (DockEvent) -> Void) -> Bool { true }

    func items() -> [(item: String, description: DockItemDescription)] {
        badges().keys.sorted().map { ($0, DockItemDescription(bundleID: $0, title: nil)) }
    }

    func badge(of bundleID: String) throws(StaleDockItem) -> String {
        guard let badge = badges()[bundleID] else { throw StaleDockItem() }
        return badge
    }

    private func badges() -> [String: String] {
        guard let data = try? Data(contentsOf: fileURL) else { return [:] }
        return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
    }
}
#endif
