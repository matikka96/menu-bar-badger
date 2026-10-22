import SwiftUI

/// A 4 pt grid. The HIG puts related controls 8 pt apart and keeps 20 pt from the window edge.
enum Spacing {
    static let xxSmall: CGFloat = 2
    static let xSmall: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let xLarge: CGFloat = 20
    static let xxLarge: CGFloat = 32
}

enum CornerRadius {
    static let panel: CGFloat = 12
    static let menuBarPreview: CGFloat = 8
}

extension View {
    /// A bordered box on the window background, such as a list with a bar of buttons below it.
    func panel() -> some View {
        clipShape(.rect(cornerRadius: CornerRadius.panel))
            .background(.background, in: .rect(cornerRadius: CornerRadius.panel))
            .overlay(RoundedRectangle(cornerRadius: CornerRadius.panel).strokeBorder(.separator))
    }
}
