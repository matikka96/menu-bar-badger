import AppKit

/// The red capsule of the Red badge style. No system control draws a badge on a status item.
final class RedBadgeView: NSView {
    private static let font = NSFont.systemFont(ofSize: 6.5, weight: .bold)
    private static let extraWidth: CGFloat = 3
    private static let extraHeight: CGFloat = 4

    static func size(of text: String) -> NSSize {
        let textWidth = (text as NSString).size(withAttributes: [.font: font]).width
        let height = (font.ascender - font.descender + extraHeight).rounded(.up)
        return NSSize(width: max((textWidth + extraWidth).rounded(.up), height), height: height)
    }

    static func fits(_ text: String) -> Bool {
        size(of: text).width <= ItemIcons.size
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
