import Foundation

public struct DockItemDescription: Sendable, Equatable {
    public var bundleID: String?
    public var title: String?

    public init(bundleID: String?, title: String?) {
        self.bundleID = bundleID
        self.title = title
    }
}

public enum DockMatch {
    public static func index(forBundleID bundleID: String, displayName: String, in items: [DockItemDescription]) -> Int? {
        items.firstIndex { $0.bundleID == bundleID }
            ?? items.firstIndex { $0.bundleID == nil && $0.title == displayName }
    }
}
