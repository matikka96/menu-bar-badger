import SwiftUI

/// A grouped `Form` on macOS 26 keeps at least 20 pt at each side, makes its sections at most 704 pt wide and
/// ignores `contentMargins`. The window width lets the sections fill it with the standard margin.
enum SettingsLayout {
    static let groupedFormInset: CGFloat = 20
    static let groupedFormMaxWidth: CGFloat = 704
    /// The distance from the edge of a section to the content of its rows.
    static let groupedRowInset: CGFloat = 10
    static let width = groupedFormMaxWidth + 2 * Spacing.medium
}

extension View {
    /// Puts the sections of a grouped `Form` at this distance from the edges of the space it gets. The form then
    /// spreads into the neighbouring views, so it draws no background.
    func groupedFormMargin(_ margin: CGFloat) -> some View {
        scrollContentBackground(.hidden)
            .padding(.horizontal, margin - SettingsLayout.groupedFormInset)
    }
}

/// A form row: the title, a hint below it, and the control at the trailing edge, centred vertically. The hint
/// takes the space of its longest variant, so that a change of the hint never moves the rows below.
struct SettingRow<Control: View, Hint: View>: View {
    let title: LocalizedStringKey
    var hintVariants: [Text] = []
    @ViewBuilder var hint: Hint
    @ViewBuilder var control: Control

    var body: some View {
        HStack(spacing: Spacing.large) {
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                Text(title)
                if !hintVariants.isEmpty {
                    ZStack(alignment: .topLeading) {
                        ForEach(hintVariants.indices, id: \.self) { index in
                            hintVariants[index].hidden()
                        }
                        hint
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            control
                .fixedSize()
        }
    }
}

extension SettingRow where Hint == Text? {
    init(_ title: LocalizedStringKey, hint: Text?, hintVariants: [Text], @ViewBuilder control: () -> Control) {
        self.init(title: title, hintVariants: hintVariants, hint: { hint }, control: control)
    }
}
