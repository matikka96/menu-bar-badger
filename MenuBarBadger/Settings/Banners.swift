import AppKit
import BadgerCore
import SwiftUI

struct Banners: View {
    let model: AppModel

    var body: some View {
        if model.configError != nil || model.isTrusted == false {
            VStack(spacing: Spacing.small) {
                if let error = model.configError {
                    ConfigErrorBanner(model: model, error: error)
                }
                if model.isTrusted == false {
                    Banner(
                        title: Text("\(AppInfo.name) can't read Dock badges"),
                        message: Text("Turn on \(AppInfo.name) in Privacy & Security › Accessibility.")
                    ) {
                        Button("Open System Settings", action: AccessibilityPermission.requestInSystemSettings)
                    }
                    .accessibilityIdentifier("accessibilityBanner")
                }
            }
        }
    }
}

private struct ConfigErrorBanner: View {
    let model: AppModel
    let error: ConfigError

    var body: some View {
        Group {
            if error == .missing {
                Banner(title: Text("The config file is missing"), message: Text(verbatim: ConfigLocation.displayPath)) {
                    Button("Create It") { model.createMissingConfigFile() }
                }
            } else {
                Banner(title: Text("The config file has an error"), message: Text(verbatim: error.message)) {
                    Button("Show in Finder", action: ConfigLocation.showInFinder)
                    Button("Reload") { model.reloadConfig() }
                }
            }
        }
        .accessibilityIdentifier("configErrorBanner")
    }
}

private struct Banner<Actions: View>: View {
    let title: Text
    let message: Text
    @ViewBuilder var actions: Actions

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.medium) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.yellow)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                title.fontWeight(.semibold)
                message
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            HStack {
                actions
            }
            .fixedSize()
        }
        .padding(Spacing.medium)
        .background(.yellow.opacity(0.12), in: .rect(cornerRadius: CornerRadius.panel))
        .accessibilityElement(children: .contain)
    }
}

@MainActor
extension ConfigError {
    var message: String {
        switch self {
        case .missing:
            String(localized: "The config file is missing")
        case .unreadable(let reason):
            reason
        case .invalidJSON(_, let line?, let column?):
            String(localized: "The JSON is not valid at line \(line), column \(column).")
        case .invalidJSON(let message, _, _), .invalidValue(let message):
            message
        case .newerVersion:
            String(localized: "This config file is from a newer version of \(AppInfo.name).")
        }
    }
}
