import AppKit
import Observation

/// The apps that the add sheet offers: the application bundles that Spotlight knows in the application folders,
/// and the running regular apps.
@Observable
final class AppCatalog {
    struct Entry: Identifiable, Equatable {
        let bundleID: String
        let name: String
        let url: URL

        var id: String { bundleID }
    }

    private(set) var entries: [Entry] = []
    private(set) var hasFirstResults = false

    @ObservationIgnored private var spotlightEntries: [String: Entry] = [:]
    @ObservationIgnored private var query: NSMetadataQuery?
    @ObservationIgnored private var observer: NSObjectProtocol?

    private static let preferredFolders = ["/Applications/", "/System/Applications/"]
    private static var folders: [URL] {
        preferredFolders.map { URL(fileURLWithPath: $0) }
            + [FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")]
    }

    /// Shows the running apps at once, and asks Spotlight again for the installed apps.
    func refresh() {
        mergeEntries()
        guard query == nil else { return }
        let query = NSMetadataQuery()
        query.predicate = NSPredicate(format: "%K == 'com.apple.application-bundle'", NSMetadataItemContentTypeKey)
        query.searchScopes = Self.folders
        observer = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidFinishGathering, object: query, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.finishGathering() }
        }
        self.query = query
        query.start()
    }

    private func finishGathering() {
        guard let query else { return }
        query.disableUpdates()
        spotlightEntries = Self.entries(from: query.results)
        query.stop()
        observer.map(NotificationCenter.default.removeObserver)
        observer = nil
        self.query = nil
        hasFirstResults = true
        mergeEntries()
    }

    private func mergeEntries() {
        var byBundleID = spotlightEntries
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            guard let bundleID = app.bundleIdentifier, byBundleID[bundleID] == nil, let url = app.bundleURL else { continue }
            byBundleID[bundleID] = Entry(bundleID: bundleID, name: AppState.displayName(of: url), url: url)
        }
        let sorted = byBundleID.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        if sorted != entries {
            entries = sorted
        }
    }

    private static func entries(from results: [Any]) -> [String: Entry] {
        var byBundleID: [String: Entry] = [:]
        for case let item as NSMetadataItem in results {
            guard let path = item.value(forAttribute: NSMetadataItemPathKey) as? String,
                  let bundleID = item.value(forAttribute: "kMDItemCFBundleIdentifier") as? String, !bundleID.isEmpty
            else { continue }
            let url = URL(fileURLWithPath: path)
            if isInsideAnotherApp(url) { continue }
            if let existing = byBundleID[bundleID], isPreferred(existing.url) || !isPreferred(url) { continue }
            byBundleID[bundleID] = Entry(bundleID: bundleID, name: AppState.displayName(of: url), url: url)
        }
        return byBundleID
    }

    private static func isInsideAnotherApp(_ url: URL) -> Bool {
        url.deletingLastPathComponent().pathComponents.contains { $0.hasSuffix(".app") }
    }

    private static func isPreferred(_ url: URL) -> Bool {
        preferredFolders.contains { url.path.hasPrefix($0) }
    }
}
