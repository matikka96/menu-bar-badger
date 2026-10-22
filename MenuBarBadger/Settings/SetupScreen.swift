import AppKit
import BadgerCore
import SwiftUI

struct SetupScreen: View {
    private static let iconSize: CGFloat = 48

    let model: AppModel
    let onDone: () -> Void

    private var isTrusted: Bool { model.isTrusted == true }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.medium) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: Self.iconSize, height: Self.iconSize)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                    Text("Welcome to \(AppInfo.name)")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Only Accessibility is required. You can change the preferences later.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.medium + SettingsLayout.groupedRowInset)
            .padding(.top, Spacing.xLarge)
            Form {
                Section("Required") {
                    AccessibilityStep(isTrusted: isTrusted)
                }
                Section("Preferences") {
                    VStack(alignment: .leading, spacing: Spacing.small) {
                        MenuBarPreview(style: model.config.badgeStyle, iconMode: model.config.newAppIcon)
                        Text("Preview with Mail as an example.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Group {
                        SetupStep(symbol: "circle.lefthalf.filled") {
                            IconStep(model: model)
                        }
                        SetupStep(symbol: "app.badge") {
                            SettingRow("Badge style", hint: model.config.badgeStyle.hint, hintVariants: BadgeStyle.allCases.map(\.hint)) {
                                BadgeStylePicker(selection: model.configBinding(\.badgeStyle))
                                    .accessibilityIdentifier("badgeStyle")
                            }
                        }
                    }
                    .disabled(!model.canChangeConfig)
                    SetupStep(symbol: "power") {
                        LoginItemRow(model: model)
                    }
                }
            }
            .formStyle(.grouped)
            .groupedFormMargin(Spacing.medium)
            .scrollDisabled(true)
            .fixedSize(horizontal: false, vertical: true)
            Divider()
                .padding(.horizontal, Spacing.medium)
            HStack {
                Text(isTrusted ? "You can change all of this later in Settings." : "Allow Accessibility to finish the setup.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Done", action: onDone)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isTrusted)
                    .accessibilityIdentifier("setupDone")
            }
            .padding(.horizontal, Spacing.medium + SettingsLayout.groupedRowInset)
            .padding(.vertical, Spacing.large)
        }
        .frame(width: SettingsLayout.width)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("setupScreen")
    }
}

/// A form row with a symbol in a leading column, so that the titles of all steps align.
private struct SetupStep<Content: View>: View {
    private static var symbolWidth: CGFloat { 20 }

    let symbol: String
    var symbolStyle = AnyShapeStyle(.secondary)
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.medium) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(symbolStyle)
                .frame(width: Self.symbolWidth)
                .accessibilityHidden(true)
            content
        }
    }
}

private struct AccessibilityStep: View {
    let isTrusted: Bool
    @State private var hasOpenedSettings = false

    private var neededHint: Text { Text("\(AppInfo.name) needs it to read the Dock badges.") }
    private var waitingHint: Text { Text("Turn on \(AppInfo.name) in System Settings. This window updates by itself.") }
    private var allowedHint: Text { Text("\(AppInfo.name) can read Dock badges now.") }

    var body: some View {
        SetupStep(
            symbol: isTrusted ? "checkmark.circle.fill" : "circle",
            symbolStyle: isTrusted ? AnyShapeStyle(.green) : AnyShapeStyle(.tertiary)
        ) {
            SettingRow(
                "Allow Accessibility",
                hint: isTrusted ? allowedHint : hasOpenedSettings ? waitingHint : neededHint,
                hintVariants: [neededHint, waitingHint, allowedHint]
            ) {
                if isTrusted {
                    Text("Allowed")
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: Spacing.small) {
                        if hasOpenedSettings {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Button("Open Accessibility Settings") {
                            hasOpenedSettings = true
                            AccessibilityPermission.requestInSystemSettings()
                        }
                        .accessibilityIdentifier("setupOpenSettings")
                    }
                }
            }
        }
    }
}

private struct IconStep: View {
    let model: AppModel

    private static func hint(_ mode: IconMode) -> Text {
        Text("\(mode.hint) You can change it for each app later.", comment: "The hint of the icon mode for new apps. The first part is the hint of the icon mode.")
    }

    var body: some View {
        SettingRow("Icon", hint: Self.hint(model.config.newAppIcon), hintVariants: IconMode.allCases.map(Self.hint)) {
            IconModePicker(selection: model.configBinding(\.newAppIcon))
                .accessibilityIdentifier("setupIconMode")
        }
    }
}
