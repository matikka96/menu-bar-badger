import AppKit
import BadgerCore

/// The icon, the text of the Number style and the capsule of the Red badge style on an item button. The status item
/// and the menu bar preview of the setup screen both draw with it.
final class ItemFace {
    struct Look: Equatable {
        var icon: ItemIcons.Source
        var variant: ItemIcons.Variant
        var title: String
        var redBadgeLabel: String?

        init(badge: String, style: BadgeStyle, icon: ItemIcons.Source, variant: ItemIcons.Variant = .plain) {
            self.icon = icon
            self.variant = variant
            title = style == .number ? badge : ""
            redBadgeLabel = style == .redBadge && !badge.isEmpty
                ? RedBadgeLabel.label(for: badge, fits: RedBadgeView.fits)
                : nil
        }
    }

    private let icons = ItemIcons()
    private let redBadge = RedBadgeView()

    func install(in button: NSButton) {
        button.font = .monospacedDigitSystemFont(ofSize: NSFont.menuBarFont(ofSize: 0).pointSize, weight: .regular)
        button.addSubview(redBadge)
        let corner = ItemIcons.itemSize / 2
        NSLayoutConstraint.activate([
            redBadge.trailingAnchor.constraint(equalTo: button.centerXAnchor, constant: corner + RedBadgeView.trailingOverhang),
            redBadge.topAnchor.constraint(equalTo: button.centerYAnchor, constant: -corner - RedBadgeView.topOverhang),
        ])
    }

    func draw(_ look: Look, in button: NSButton) {
        button.image = icons.image(look.variant, for: look.icon)
        button.title = look.title
        button.imagePosition = look.title.isEmpty ? .imageOnly : .imageLeading
        redBadge.text = look.redBadgeLabel ?? ""
        redBadge.isHidden = look.redBadgeLabel == nil
    }
}
