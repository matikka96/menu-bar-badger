import AppKit
import BadgerCore

/// The icon images of one item. Each image is made one time, and again only when the app, the icon mode or the
/// screen scale changes.
final class ItemIcons {
    static let size: CGFloat = 18
    private static let shrunkSize: CGFloat = 15
    private static let defaultSymbol = "app.badge"

    struct Source: Equatable {
        var appURL: URL?
        var mode: IconMode
        var scale: CGFloat
    }

    enum Variant {
        case plain
        /// Gives room for the red badge capsule at the top-right corner.
        case shrunk
        /// Grey for a Color icon. The button reduces the opacity.
        case dimmed
    }

    private var source: Source?
    private var images: [Variant: NSImage] = [:]

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
        case .shrunk: return shrunk(plain)
        case .dimmed: return plain.isTemplate ? plain : grey(plain)
        }
    }

    private func makePlain(for source: Source) -> NSImage {
        guard let appURL = source.appURL else { return Self.defaultIcon() }
        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        if source.mode == .monochrome,
           let template = MonochromeIcon.make(from: icon, size: Self.size, scale: source.scale) {
            return template
        }
        let sized = icon.copy() as? NSImage ?? icon
        sized.size = NSSize(width: Self.size, height: Self.size)
        return sized
    }

    private static func defaultIcon() -> NSImage {
        let configuration = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        let symbol = NSImage(systemSymbolName: defaultSymbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration) ?? NSImage()
        symbol.isTemplate = true
        return symbol
    }

    private func shrunk(_ image: NSImage) -> NSImage {
        let canvas = NSSize(width: Self.size, height: Self.size)
        let result = NSImage(size: canvas, flipped: false) { _ in
            image.draw(in: NSRect(x: 0, y: 0, width: Self.shrunkSize, height: Self.shrunkSize))
            return true
        }
        result.isTemplate = image.isTemplate
        return result
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
