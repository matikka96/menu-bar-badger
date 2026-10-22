import BadgerCore
import SwiftUI

struct AppsTab: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(spacing: Spacing.medium) {
            Banners(model: model)
            HStack(alignment: .top, spacing: Spacing.medium) {
                AppList(model: model)
                    .frame(width: 220)
                    .zIndex(1)
                AppDetail(model: model)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: 400)
            .disabled(!model.canChangeConfig)
        }
        .padding(Spacing.medium)
        .frame(width: SettingsLayout.width)
        .sheet(isPresented: $model.isAddSheetPresented) {
            AddAppSheet(model: model)
        }
    }
}

private struct AppList: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $model.selectedBundleID) {
                ForEach(model.apps) { app in
                    AppRow(app: app, iconMode: model.settings(of: app.bundleID)?.icon ?? .color)
                        .tag(app.bundleID)
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .contextMenu(forSelectionType: String.self) { bundleIDs in
                if let bundleID = bundleIDs.first {
                    Button("Remove") { model.removeApp(bundleID) }
                }
            }
            .onDeleteCommand(perform: removeSelected)
            .overlay {
                if model.apps.isEmpty {
                    EmptyPaneText(title: "No apps yet", message: "Click + to add an app.")
                }
            }
            .accessibilityIdentifier("appsList")
            Divider()
            HStack(spacing: 0) {
                Button {
                    model.isAddSheetPresented = true
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 24, height: 22)
                }
                .accessibilityLabel(Text("Add App"))
                .accessibilityIdentifier("addApp")
                Divider()
                    .frame(height: 16)
                Button(action: removeSelected) {
                    Image(systemName: "minus")
                        .frame(width: 24, height: 22)
                }
                .disabled(model.selectedBundleID == nil)
                .accessibilityLabel(Text("Remove App"))
                .accessibilityIdentifier("removeApp")
                Spacer()
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, Spacing.xSmall)
        }
        .panel()
    }

    private func removeSelected() {
        guard let bundleID = model.selectedBundleID else { return }
        model.removeApp(bundleID)
    }
}

private struct AppRow: View {
    let app: AppState
    let iconMode: IconMode

    var body: some View {
        HStack(spacing: Spacing.small) {
            AppIcon(appURL: app.appURL, size: 24, mode: iconMode)
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: app.name)
                    .lineLimit(1)
                Text(verbatim: app.listStatus)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, Spacing.xxSmall)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("appRow")
    }
}

private struct AppDetail: View {
    let model: AppModel

    var body: some View {
        if let bundleID = model.selectedBundleID,
           let app = model.apps.first(where: { $0.bundleID == bundleID }),
           let settings = model.settings(of: bundleID) {
            AppOptions(model: model, app: app, settings: settings)
        } else {
            EmptyPaneText(title: "Select an app")
        }
    }
}

private struct EmptyPaneText: View {
    let title: LocalizedStringKey
    var message: LocalizedStringKey?

    var body: some View {
        VStack(spacing: Spacing.xSmall) {
            Text(title)
                .fontWeight(.medium)
            if let message {
                Text(message)
                    .font(.subheadline)
            }
        }
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(Spacing.medium)
    }
}

private struct AppOptions: View {
    let model: AppModel
    let app: AppState
    let settings: MonitoredApp

    private var isIconOnly: Bool { model.config.badgeStyle == .iconOnly }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Spacing.medium) {
                AppIcon(appURL: app.appURL, size: 48, mode: settings.icon)
                VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                    Text(verbatim: app.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Text(verbatim: app.detailStatus)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
            }
            .padding(.top, Spacing.xSmall)
            Form {
                Section {
                    SettingRow("Icon", hint: settings.icon.hint, hintVariants: IconMode.allCases.map(\.hint)) {
                        IconModePicker(selection: binding(\.icon))
                            .accessibilityIdentifier("appIconMode")
                    }
                    SettingRow(
                        "Show arrow for new badges",
                        hint: isIconOnly ? Self.iconOnlyHint : Self.arrowHint,
                        hintVariants: [Self.arrowHint, Self.iconOnlyHint]
                    ) {
                        Toggle("Show arrow for new badges", isOn: binding(\.arrow))
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .disabled(isIconOnly)
                            .accessibilityIdentifier("appArrow")
                    }
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .groupedFormMargin(0)
            HStack {
                Spacer()
                Button("Open \(app.name)") {
                    AppActivation.open(bundleID: app.bundleID, appURL: app.appURL)
                }
                .disabled(!app.isInstalled)
                .accessibilityIdentifier("openApp")
            }
            Spacer(minLength: 0)
        }
    }

    private static let arrowHint = Text("A red arrow under the menu bar item points to a new badge. It stays until you click the item or open the app.")
    private static let iconOnlyHint = Text("Doesn't apply to Icon only.")

    private func binding<Value>(_ keyPath: WritableKeyPath<MonitoredApp, Value>) -> Binding<Value> {
        Binding {
            settings[keyPath: keyPath]
        } set: { value in
            model.changeApp(app.bundleID) { $0[keyPath: keyPath] = value }
        }
    }
}
