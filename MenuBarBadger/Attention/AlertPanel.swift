import AppKit
import BadgerCore
import SwiftUI

final class AlertPanel: AttentionPanel {
    static let fadeDuration: TimeInterval = 0.15
    private static let iconSize: CGFloat = 20

    private let hosting = NSHostingView(rootView: AlertContent(icon: NSImage(), badge: ""))
    private let icons = ItemIcons(size: iconSize)

    init(onClick: @escaping () -> Void) {
        let clickArea = ClickArea(onClick: onClick)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        clickArea.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: clickArea.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: clickArea.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: clickArea.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: clickArea.bottomAnchor),
        ])
        let glass = NSGlassEffectView()
        glass.cornerRadius = CornerRadius.panel
        glass.contentView = clickArea
        super.init(level: Self.alertLevel, content: glass)
    }

    func update(state: AppState, iconMode: IconMode) {
        let scale = screen?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        let icon = icons.image(.plain, for: ItemIcons.Source(appURL: state.appURL, mode: iconMode, scale: scale))
        hosting.rootView = AlertContent(icon: icon, badge: state.badge)
        contentView?.setAccessibilityLabel(String(localized: "\(state.name), \(state.badge) new"))
        setContentSize(hosting.fittingSize)
        invalidateShadow()
    }
}

private struct AlertContent: View {
    let icon: NSImage
    let badge: String

    var body: some View {
        HStack(spacing: Spacing.small) {
            Image(nsImage: icon)
            Text(verbatim: badge)
                .font(.body.bold())
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.small)
        .fixedSize()
    }
}

/// The first click counts, also while the panel is not key.
private final class ClickArea: NSView {
    private let onClick: () -> Void

    init(onClick: @escaping () -> Void) {
        self.onClick = onClick
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { super.hitTest(point) == nil ? nil : self }
    override func mouseDown(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) { onClick() }
    override func accessibilityPerformPress() -> Bool {
        onClick()
        return true
    }
}
