import AppKit
import BadgerCore

/// The icon images of one item or alert. Each image is made one time, and again only when the app, the icon mode or
/// the screen scale changes.
final class ItemIcons {
    static let itemSize: CGFloat = 22
    private static let defaultSymbol = "app.badge"
    private static let defaultSymbolScale: CGFloat = 15 / 18

    struct Source: Equatable {
        var appURL: URL?
        var mode: IconMode
        var scale: CGFloat
    }

    enum Variant {
        case plain
        /// Grey for a Color icon. The button reduces the opacity.
        case dimmed
    }

    private let size: CGFloat
    private var source: Source?
    private var images: [Variant: NSImage] = [:]

    init(size: CGFloat = itemSize) {
        self.size = size
    }

    func image(_ variant: Variant, for source: Source) -> NSImage {
        if source != self.source {
            self.source = source
            images = [:]
        }
        if let image = images[variant] { return image }
        let image = make(variant, for: source)
        images[variant] = image
        return image
    }

    private func make(_ variant: Variant, for source: Source) -> NSImage {
        let plain = images[.plain] ?? makePlain(for: source)
        images[.plain] = plain
        switch variant {
        case .plain: return plain
        case .dimmed: return plain.isTemplate ? plain : grey(plain)
        }
    }

    private func makePlain(for source: Source) -> NSImage {
        guard let appURL = source.appURL else { return defaultIcon() }
        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        let sized = icon.copy() as? NSImage ?? icon
        sized.size = NSSize(width: size, height: size)
        return source.mode == .monochrome ? grey(sized) : sized
    }

    private func defaultIcon() -> NSImage {
        let configuration = NSImage.SymbolConfiguration(pointSize: size * Self.defaultSymbolScale, weight: .regular)
        let symbol = NSImage(systemSymbolName: Self.defaultSymbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration) ?? NSImage()
        symbol.isTemplate = true
        return symbol
    }

    private func grey(_ image: NSImage) -> NSImage {
        NSImage(size: image.size, flipped: false) { rect in
            image.draw(in: rect)
            NSColor.gray.setFill()
            rect.fill(using: .saturation)
            image.draw(in: rect, from: .zero, operation: .destinationIn, fraction: 1)
            return true
        }
    }
}
