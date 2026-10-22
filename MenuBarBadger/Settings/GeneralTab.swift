import AppKit
import BadgerCore
import KeyboardShortcuts
import ServiceManagement
import SwiftUI

struct GeneralTab: View {
    let model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            Banners(model: model)
                .padding([.horizontal, .top], Spacing.medium)
            Form {
                Group {
                    MenuBarSection(model: model)
                    AlertsSection(model: model)
                    Section("General") {
                        LoginItemRow(model: model)
                        ShortcutRow(model: model)
                    }
                }
                .disabled(!model.canChangeConfig)
                Section("Config File") {
                    HStack(spacing: Spacing.large) {
                        Text(verbatim: ConfigLocation.displayPath)
                            .textSelection(.enabled)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer(minLength: 0)
                        Button("Show in Finder", action: ConfigLocation.showInFinder)
                            .accessibilityIdentifier("showConfigFile")
                    }
                }
            }
            .formStyle(.grouped)
            .groupedFormMargin(Spacing.medium)
            .scrollDisabled(true)
            .fixedSize(horizontal: false, vertical: true)
            HStack {
                Text("\(AppInfo.name) \(AppInfo.version)", comment: "The app name and its version, for example MenuBarBadger 1.0.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("About", action: AboutPanel.show)
                    .accessibilityIdentifier("about")
                Button("Quit") { NSApp.terminate(nil) }
                    .accessibilityIdentifier("quit")
            }
            .padding(.horizontal, Spacing.medium + SettingsLayout.groupedRowInset)
            .padding(.bottom, Spacing.medium)
        }
        .frame(width: SettingsLayout.width)
    }
}

private struct MenuBarSection: View {
    let model: AppModel

    var body: some View {
        Section("Menu Bar") {
            SettingRow("Badge", hint: model.config.badgeStyle.hint, hintVariants: BadgeStyle.allCases.map(\.hint)) {
                BadgeStylePicker(selection: model.configBinding(\.badgeStyle))
                    .accessibilityIdentifier("badgeStyle")
            }
            SettingRow(
                "When there's nothing new",
                hint: Self.nothingNewHints[model.config.whenNothingNew],
                hintVariants: Array(Self.nothingNewHints.values)
            ) {
                Picker("When there's nothing new", selection: model.configBinding(\.whenNothingNew)) {
                    Text("Show").tag(NothingNewMode.show)
                    Text("Dim").tag(NothingNewMode.dim)
                    Text("Hide").tag(NothingNewMode.hide)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityIdentifier("whenNothingNew")
            }
            SettingRow(
                "Hide while the app isn't running",
                hint: Text("The icon comes back when the app starts."),
                hintVariants: [Text("The icon comes back when the app starts.")]
            ) {
                Toggle("Hide while the app isn't running", isOn: model.configBinding(\.hideWhenNotRunning))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .accessibilityIdentifier("hideWhenNotRunning")
            }
        }
    }

    private static let nothingNewHints: [NothingNewMode: Text] = [
        .show: Text("The icon stays as it is."),
        .dim: Text("The icon is dimmed."),
        .hide: Text("The icon is hidden until something arrives."),
    ]
}

private struct AlertsSection: View {
    let model: AppModel

    var body: some View {
        let isIconOnly = model.config.badgeStyle == .iconOnly
        let normalHint = Text("For example, while an app is full screen.")
        let iconOnlyHint = Text("Doesn't apply to Icon only.")
        Section("Alerts") {
            SettingRow(
                "Show an alert when the menu bar is hidden",
                hint: isIconOnly ? iconOnlyHint : normalHint,
                hintVariants: [normalHint, iconOnlyHint]
            ) {
                Toggle("Show an alert when the menu bar is hidden", isOn: model.configBinding(\.alertWhenMenuBarHidden))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .disabled(isIconOnly)
                    .accessibilityIdentifier("alertWhenMenuBarHidden")
            }
        }
    }
}

struct LoginItemRow: View {
    let model: AppModel

    private var status: SMAppService.Status { model.loginItemStatus }
    private var normalHint: Text { Text("The badges stay in the menu bar after a restart.") }
    private var approvalHint: Text { Text("Needs your approval in System Settings.") }
    private var notInApplicationsHint: Text { Text("Move \(AppInfo.name) to the Applications folder to use this.") }

    var body: some View {
        SettingRow(title: "Launch at login", hintVariants: [normalHint, approvalHint, notInApplicationsHint]) {
            if let error = model.loginItemUnregisterError ?? model.loginItemRegisterError {
                Text(verbatim: error)
            } else if status == .requiresApproval {
                Label {
                    approvalHint
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                }
            } else if !LoginItem.isInApplicationsFolder {
                notInApplicationsHint
            } else {
                normalHint
            }
        } control: {
            HStack {
                if status == .requiresApproval {
                    Button("Open Login Items", action: LoginItem.openSystemSettings)
                }
                Toggle("Launch at login", isOn: Binding(get: { isOn }, set: { model.setLoginItemEnabled($0) }))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .disabled(!canEnable && !isOn)
                    .accessibilityIdentifier("launchAtLogin")
            }
        }
    }

    private var isOn: Bool {
        status == .enabled || status == .requiresApproval
    }

    private var canEnable: Bool {
        LoginItem.isInApplicationsFolder && model.loginItemRegisterError == nil
    }
}

private struct ShortcutRow: View {
    let model: AppModel
    @State private var refusal: GlobalShortcut.Refusal?

    private var normalHint: Text { Text("Click the field, then press the keys.") }
    private var needsCommandOrControlHint: Text { Text("Use ⌘ or ⌃ in the shortcut.") }
    private var unknownKeyHint: Text { Text("Use another key.") }

    private var hint: Text {
        switch refusal {
        case nil: normalHint
        case .needsCommandOrControl: needsCommandOrControlHint
        case .unknownKey: unknownKeyHint
        }
    }

    var body: some View {
        SettingRow(
            "Shortcut to open settings",
            hint: hint,
            hintVariants: [normalHint, needsCommandOrControlHint, unknownKeyHint]
        ) {
            KeyboardShortcuts.Recorder(for: .openSettings) { recorded in
                refusal = GlobalShortcut.record(recorded, in: model)
            }
            // The recorder is an AppKit view, which does not follow `disabled`.
            .allowsHitTesting(model.canChangeConfig)
            .opacity(model.canChangeConfig ? 1 : 0.5)
            .accessibilityLabel(Text("Shortcut to open settings"))
            .accessibilityIdentifier("openSettingsShortcut")
        }
    }
}

extension AppModel {
    func configBinding<Value: Equatable>(_ keyPath: WritableKeyPath<Config, Value>) -> Binding<Value> {
        Binding {
            self.config[keyPath: keyPath]
        } set: { value in
            self.changeConfig { $0[keyPath: keyPath] = value }
        }
    }
}
