import Foundation

public struct MonitoredDockApp: Sendable, Equatable {
    public var bundleID: String
    public var displayName: String

    public init(bundleID: String, displayName: String) {
        self.bundleID = bundleID
        self.displayName = displayName
    }
}

public struct DockAppState: Sendable, Equatable {
    public static let absent = DockAppState(badge: "", isDockItemFound: false)

    public var badge: String
    public var isDockItemFound: Bool

    public init(badge: String, isDockItemFound: Bool) {
        self.badge = badge
        self.isDockItemFound = isDockItemFound
    }
}

public enum DockReaderEvent: Sendable, Equatable {
    case permission(Bool)
    /// Only the apps whose state changed, by bundle ID.
    case states([String: DockAppState])
}

public protocol DockReading: Actor {
    nonisolated var events: AsyncStream<DockReaderEvent> { get }
    func start()
    func stop()
    func setApps(_ apps: [MonitoredDockApp])
    func appDidLaunchOrTerminate(bundleID: String)
    func setScreensAsleep(_ areScreensAsleep: Bool)
}

public actor DockReader<Source: DockSource>: DockReading {
    public static var pollInterval: Duration { .seconds(1) }
    public static var pollTolerance: Duration { .milliseconds(250) }
    public static var fullLookupInterval: Duration { .seconds(10) }

    public nonisolated let events: AsyncStream<DockReaderEvent>
    private let continuation: AsyncStream<DockReaderEvent>.Continuation
    private let source: Source
    private let clock = ContinuousClock()

    private var apps: [MonitoredDockApp] = []
    private var items: [String: Source.Item] = [:]
    private var reported: [String: DockAppState] = [:]
    private var isTrusted: Bool?
    private var dockProcessID: Int32?
    private var isObservingDock = false
    private var lastFullLookup: ContinuousClock.Instant?
    private var areScreensAsleep = false
    private var loop: Task<Void, Never>?

    public init(source: sending Source) {
        self.source = source
        (events, continuation) = AsyncStream.makeStream()
    }

    public func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            let clock = ContinuousClock()
            while !Task.isCancelled {
                let next = clock.now + Self.pollInterval
                await self?.tick()
                try? await Task.sleep(until: next, tolerance: Self.pollTolerance, clock: clock)
            }
        }
    }

    public func stop() {
        loop?.cancel()
        loop = nil
    }

    public func setApps(_ newApps: [MonitoredDockApp]) {
        guard newApps != apps else { return }
        let kept = Set(newApps.map(\.bundleID))
        items = items.filter { kept.contains($0.key) }
        reported = reported.filter { kept.contains($0.key) }
        let changed = newApps.filter { !apps.contains($0) }
        apps = newApps
        guard canPoll else {
            lastFullLookup = nil
            return
        }
        lookUp(changed)
        poll()
    }

    public func appDidLaunchOrTerminate(bundleID: String) {
        guard canPoll else { return }
        lookUp(apps.filter { $0.bundleID == bundleID })
        poll()
    }

    public func setScreensAsleep(_ areScreensAsleep: Bool) {
        self.areScreensAsleep = areScreensAsleep
        guard !areScreensAsleep else { return }
        lastFullLookup = nil
        tick()
    }

    func handle(_ event: DockEvent) {
        guard canPoll else {
            lastFullLookup = nil
            return
        }
        if case .elementCreated = event {
            lookUp(apps.filter { items[$0.bundleID] == nil })
        }
        poll()
    }

    private var canPoll: Bool {
        isTrusted == true && !areScreensAsleep && !apps.isEmpty
    }

    private func tick() {
        guard !areScreensAsleep else { return }
        let trusted = source.isTrusted()
        if trusted != isTrusted {
            isTrusted = trusted
            continuation.yield(.permission(trusted))
        }
        guard canPoll else { return }
        poll()
    }

    @discardableResult
    func poll() -> [String: DockAppState] {
        attachToDockIfRestarted()
        if lastFullLookup.map({ clock.now - $0 >= Self.fullLookupInterval }) ?? true {
            if lookUp(apps) { lastFullLookup = clock.now }
        }
        var snapshot: [(item: Source.Item, description: DockItemDescription)]?
        var changes: [String: DockAppState] = [:]
        for app in apps {
            guard let state = read(app, snapshot: &snapshot),
                  state != reported[app.bundleID, default: .absent]
            else { continue }
            reported[app.bundleID] = state
            changes[app.bundleID] = state
        }
        if !changes.isEmpty { continuation.yield(.states(changes)) }
        return changes
    }

    /// Returns nil while the Dock is not ready, so that the last state stays.
    private func read(
        _ app: MonitoredDockApp,
        snapshot: inout [(item: Source.Item, description: DockItemDescription)]?
    ) -> DockAppState? {
        guard let item = items[app.bundleID] else { return .absent }
        if let badge = try? source.badge(of: item) {
            return DockAppState(badge: badge, isDockItemFound: true)
        }
        let current = snapshot ?? source.items()
        snapshot = current
        guard !current.isEmpty else { return nil }
        guard let replacement = match(app, in: current), let badge = try? source.badge(of: replacement) else {
            items[app.bundleID] = nil
            return .absent
        }
        items[app.bundleID] = replacement
        return DockAppState(badge: badge, isDockItemFound: true)
    }

    private func attachToDockIfRestarted() {
        let processID = source.dockProcessID()
        if processID != dockProcessID {
            dockProcessID = processID
            isObservingDock = false
            lastFullLookup = nil
        }
        guard !isObservingDock, let processID else { return }
        isObservingDock = source.observe(processID: processID) { [weak self] event in
            Task { await self?.handle(event) }
        }
    }

    /// A Dock with zero items is not ready: the old items stay. Returns false then.
    @discardableResult
    private func lookUp(_ apps: [MonitoredDockApp]) -> Bool {
        guard !apps.isEmpty else { return true }
        let current = source.items()
        guard !current.isEmpty else { return false }
        for app in apps {
            items[app.bundleID] = match(app, in: current)
        }
        return true
    }

    private func match(
        _ app: MonitoredDockApp,
        in current: [(item: Source.Item, description: DockItemDescription)]
    ) -> Source.Item? {
        DockMatch.index(forBundleID: app.bundleID, displayName: app.displayName, in: current.map(\.description))
            .map { current[$0].item }
    }
}
