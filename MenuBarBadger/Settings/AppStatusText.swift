import AppKit
import BadgerCore
import SwiftUI
import UniformTypeIdentifiers

extension AppState {
    var listStatus: String {
        if !isInstalled {
            String(localized: "Not installed")
        } else if !isRunning {
            String(localized: "Not running")
        } else if badge.isEmpty {
            String(localized: "Nothing new")
        } else {
            String(localized: "\(badge) new", comment: "The status of an app. The argument is its Dock badge, for example 3.")
        }
    }

    var detailStatus: String {
        if !isInstalled {
            String(localized: "Not installed · \(bundleID)")
        } else if !isRunning {
            String(localized: "Not running")
        } else if badge.isEmpty {
            String(localized: "Running · nothing new")
        } else {
            String(localized: "Running · \(badge) new", comment: "The status of an app. The argument is its Dock badge, for example 3.")
        }
    }
}

struct AppIcon: View {
    let appURL: URL?
    let size: CGFloat
    var mode = IconMode.color

    var body: some View {
        Image(nsImage: appURL.map { NSWorkspace.shared.icon(forFile: $0.path) }
            ?? NSWorkspace.shared.icon(for: .applicationBundle))
            .resizable()
            .frame(width: size, height: size)
            .grayscale(mode == .monochrome ? 1 : 0)
            .accessibilityHidden(true)
    }
}
