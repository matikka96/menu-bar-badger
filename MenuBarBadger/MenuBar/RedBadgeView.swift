import AppKit

/// The red capsule of the Red badge style. No system control draws a badge on a status item.
/// It draws its text itself: on macOS 27, an `NSTextField` in a status item button marks the button dirty at each
/// menu bar snapshot, so the snapshots repeat each 0.1 s and take the main thread (#8).
final class RedBadgeView: NSView {
    private static let font = NSFont.systemFont(ofSize: 8, weight: .bold)
    private static let extraWidth: CGFloat = 4
    private static let extraHeight: CGFloat = 4
    /// The capsule of "99+" and of "new".
    private static let maxWidth: CGFloat = 22
    /// The capsule extends past the top-right corner of the icon, as a Dock badge does, so that it covers less of
    /// the icon.
    static let trailingOverhang: CGFloat = 5
    /// 0, because on a display without the focus, macOS clips the item to the height of the icon (#6).
    static let topOverhang: CGFloat = 0

    static func size(of text: String) -> NSSize {
        let textWidth = (text as NSString).size(withAttributes: [.font: font]).width
        let height = (font.ascender - font.descender + extraHeight).rounded(.up)
        return NSSize(width: max((textWidth + extraWidth).rounded(.up), height), height: height)
    }

    static func fits(_ text: String) -> Bool {
        size(of: text).width <= maxWidth
    }

    private static let textAttributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]

    var text = "" {
        didSet {
            needsDisplay = true
            invalidateIntrinsicContentSize()
        }
    }

    override var intrinsicContentSize: NSSize { Self.size(of: text) }

    override init(frame: NSRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.systemRed.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: bounds.height / 2, yRadius: bounds.height / 2).fill()
        let string = text as NSString
        let size = string.size(withAttributes: Self.textAttributes)
        string.draw(
            at: NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2),
            withAttributes: Self.textAttributes
        )
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
