#if DEBUG
import AppKit

struct DebugState: Encodable {
    struct Rect: Encodable {
        var x: Double
        var y: Double
        var width: Double
        var height: Double

        init(_ rect: CGRect) {
            x = rect.minX
            y = rect.minY
            width = rect.width
            height = rect.height
        }
    }

    struct Item: Encodable {
        var bundleID: String
        var badge: String
        var isDockItemFound: Bool
        var isVisible: Bool
        /// In the AppKit screen coordinates. Nil while the item is hidden.
        var frame: Rect?
        var title: String
        var redBadgeLabel: String?
        var iconMode: String
        var redrawCount: Int
    }

    struct Panel: Encodable {
        var bundleID: String
        var frame: Rect
        var level: Int
    }

    var processID: Int32
    var isTrusted: Bool?
    var items: [Item]
    var alerts: [Panel]
    var arrows: [Panel]
}

final class DebugStateWriter {
    private static let interval: Duration = .milliseconds(250)

    private let fileURL: URL
    private let state: () -> DebugState
    private let encoder = JSONEncoder()
    private var task: Task<Void, Never>?

    init(fileURL: URL, state: @escaping () -> DebugState) {
        self.fileURL = fileURL
        self.state = state
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func start() {
        task = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                write()
                try? await Task.sleep(for: Self.interval)
            }
        }
    }

    private func write() {
        guard let data = try? encoder.encode(state()) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
#endif
