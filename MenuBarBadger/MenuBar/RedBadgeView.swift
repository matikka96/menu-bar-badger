import AppKit

/// The red capsule of the Red badge style. No system control draws a badge on a status item.
final class RedBadgeView: NSView {
    private static let font = NSFont.systemFont(ofSize: 8, weight: .bold)
    private static let extraWidth: CGFloat = 4
    private static let extraHeight: CGFloat = 4
    /// The capsule of "99+" and of "new".
    private static let maxWidth: CGFloat = 22
    /// The capsule extends past the top-right corner of the icon, as a Dock badge does, so that it covers less of
    /// the icon.
    static let trailingOverhang: CGFloat = 5
    static let topOverhang: CGFloat = 2

    static func size(of text: String) -> NSSize {
        let textWidth = (text as NSString).size(withAttributes: [.font: font]).width
        let height = (font.ascender - font.descender + extraHeight).rounded(.up)
        return NSSize(width: max((textWidth + extraWidth).rounded(.up), height), height: height)
    }

    static func fits(_ text: String) -> Bool {
        size(of: text).width <= maxWidth
    }

    private let label = NSTextField(labelWithString: "")

    var text = "" {
        didSet {
            label.stringValue = text
            invalidateIntrinsicContentSize()
        }
    }

    override var intrinsicContentSize: NSSize { Self.size(of: text) }
    override var wantsUpdateLayer: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        setAccessibilityElement(false)
        label.font = Self.font
        label.textColor = .white
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func updateLayer() {
        layer?.backgroundColor = NSColor.systemRed.cgColor
        layer?.cornerRadius = bounds.height / 2
    }

    override func layout() {
        super.layout()
        needsDisplay = true
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
