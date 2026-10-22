import AppKit
import BadgerCore
import SwiftUI

struct MenuBarPreview: View {
    private static let example = AppState(bundleID: "com.apple.mail")
    private static let exampleBadge = "3"
    private static let wallpaperHeight: CGFloat = 32
    /// The menu bar of macOS 26 on a screen with no notch. `NSStatusBar.thickness` gives 22 pt, the height of
    /// the menu bar before macOS 26.
    private static let defaultBarHeight: CGFloat = 31
    private static let clock = Calendar.current.date(bySettingHour: 9, minute: 41, second: 0, of: .now) ?? .now

    let style: BadgeStyle
    let iconMode: IconMode
    @Environment(\.displayScale) private var scale

    var body: some View {
        HStack(spacing: Spacing.large) {
            Group {
                Text("Finder", comment: "An app menu in the menu bar preview.")
                    .fontWeight(.bold)
                Text("File", comment: "A menu title in the menu bar preview.")
                Text("Edit")
                Text("View", comment: "A menu title in the menu bar preview.")
            }
            .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            ItemPreview(look: ItemFace.Look(
                badge: Self.exampleBadge,
                style: style,
                icon: ItemIcons.Source(appURL: Self.example.appURL, mode: iconMode, scale: scale)
            ))
            .fixedSize()
            .padding(.horizontal, Spacing.xSmall)
            Image(systemName: "wifi")
            Image(systemName: "battery.100percent")
            Text(Self.clock, format: .dateTime.hour().minute())
        }
        .font(Font(NSFont.menuBarFont(ofSize: 0)))
        .lineLimit(1)
        .padding(.horizontal, Spacing.medium)
        .frame(height: Self.barHeight)
        .background(.bar)
        .padding(.bottom, Self.wallpaperHeight)
        .background(.gray.gradient)
        .clipShape(.rect(cornerRadius: CornerRadius.menuBarPreview))
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isImage)
        .accessibilityLabel(Text(
            "Menu bar preview, \(String(localized: style.title)) style: \(Self.example.name), \(Self.exampleBadge) new",
            comment: "VoiceOver label of the menu bar preview: the badge style, the example app and its badge."
        ))
        .accessibilityIdentifier("setupBadgePreview")
    }
}

private extension MenuBarPreview {
    static var barHeight: CGFloat {
        guard let screen = NSScreen.main else { return defaultBarHeight }
        // Zero while the menu bar hides itself.
        let height = screen.frame.maxY - screen.visibleFrame.maxY
        return height > 0 ? height : defaultBarHeight
    }
}

private struct ItemPreview: NSViewRepresentable {
    let look: ItemFace.Look

    func makeCoordinator() -> ItemFace {
        ItemFace()
    }

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(frame: .zero)
        button.isBordered = false
        button.setAccessibilityElement(false)
        context.coordinator.install(in: button)
        return button
    }

    func updateNSView(_ button: NSButton, context: Context) {
        context.coordinator.draw(look, in: button)
        button.invalidateIntrinsicContentSize()
    }
}
