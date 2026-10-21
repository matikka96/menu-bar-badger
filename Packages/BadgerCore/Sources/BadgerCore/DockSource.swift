import Foundation

public enum DockEvent: Sendable {
    case elementCreated
    case elementDestroyed
}

/// The item answered "invalid element", "cannot complete" or timed out.
public struct StaleDockItem: Error {
    public init() {}
}

/// The `DockReader` owns its source and calls it only from its own actor.
public protocol DockSource: SendableMetatype {
    associatedtype Item

    func isTrusted() -> Bool
    func dockProcessID() -> Int32?
    /// Replaces the observer of an earlier Dock process. Returns false when the Dock does not accept the observer yet.
    func observe(processID: Int32, onEvent: @escaping @Sendable (DockEvent) -> Void) -> Bool
    func items() -> [(item: Item, description: DockItemDescription)]
    func badge(of item: Item) throws(StaleDockItem) -> String
}
