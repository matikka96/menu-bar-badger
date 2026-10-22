import BadgerCore
import SwiftUI

struct BadgeStylePicker: View {
    let selection: Binding<BadgeStyle>

    var body: some View {
        Picker("Badge", selection: selection) {
            ForEach(BadgeStyle.allCases, id: \.self) { style in
                Text(style.title).tag(style)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}

struct IconModePicker: View {
    let selection: Binding<IconMode>

    var body: some View {
        Picker("Icon", selection: selection) {
            ForEach(IconMode.allCases, id: \.self) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}

extension BadgeStyle {
    var title: LocalizedStringResource {
        switch self {
        case .number: "Number"
        case .redBadge: "Red Badge"
        case .iconOnly: "Icon Only"
        }
    }

    var hint: Text {
        switch self {
        case .number: Text("Number next to the icon.")
        case .redBadge: Text("Red badge on the icon.")
        case .iconOnly: Text("Only the icon, with no alerts or arrows.")
        }
    }
}

extension IconMode {
    var title: LocalizedStringResource {
        switch self {
        case .color: "Color"
        case .monochrome: "Monochrome"
        }
    }

    var hint: Text {
        switch self {
        case .color: Text("The icon keeps the app's colours.")
        case .monochrome: Text("The icon shows in black and white.")
        }
    }
}
