import SwiftUI

struct WelcomeView: View {
    let model: AppModel
    let addApps: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            Text("Welcome to \(AppInfo.name)")
                .font(.title)
                .fontWeight(.semibold)
            if model.isTrusted == true {
                Label {
                    Text("\(AppInfo.name) can read Dock badges now.")
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                Button("Add Apps…", action: addApps)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("welcomeAddApps")
            } else {
                Text("\(AppInfo.name) shows the Dock badges of your apps in the menu bar. To read the badges, it needs the Accessibility permission.")
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open Accessibility Settings", action: AccessibilityPermission.requestInSystemSettings)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("welcomeOpenSettings")
            }
        }
        .padding(32)
        .frame(width: 420)
    }
}
