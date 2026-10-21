import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct AddAppSheet: View {
    let model: AppModel

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selection: String?
    @State private var isChoosingFromFinder = false
    @State private var finderError: LocalizedStringKey?

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var catalog: AppCatalog { model.catalog }

    private var results: [AppCatalog.Entry] {
        let text = trimmedSearchText
        guard !text.isEmpty else { return catalog.entries }
        return catalog.entries.filter {
            $0.name.range(of: text, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Text("Choose an App")
                .font(.headline)
            SearchField(text: $searchText, onMove: moveSelection(by:), onSubmit: { add(selection) }, onCancel: { dismiss() })
            List(selection: $selection) {
                ForEach(results) { entry in
                    let isAdded = model.settings(of: entry.bundleID) != nil
                    ResultRow(entry: entry, isAdded: isAdded)
                        .tag(entry.bundleID)
                        .selectionDisabled(isAdded)
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .contextMenu(forSelectionType: String.self) { _ in
            } primaryAction: { bundleIDs in
                add(bundleIDs.first)
            }
            .overlay {
                if !catalog.hasFirstResults {
                    ProgressView()
                        .controlSize(.small)
                } else if results.isEmpty, !trimmedSearchText.isEmpty {
                    Text("No app matches “\(trimmedSearchText)”.")
                        .foregroundStyle(.secondary)
                }
            }
            .panel()
            .accessibilityIdentifier("appResults")
            .disabled(!model.canChangeConfig)
            HStack {
                Button("Choose from Finder…") {
                    finderError = nil
                    isChoosingFromFinder = true
                }
                .disabled(!model.canChangeConfig)
                .accessibilityIdentifier("chooseFromFinder")
                if let finderError {
                    Text(finderError)
                        .foregroundStyle(.red)
                }
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("cancelAdd")
                Button("Add") { add(selection) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selection == nil || !model.canChangeConfig)
                    .accessibilityIdentifier("confirmAdd")
            }
        }
        .padding(Spacing.xLarge)
        .frame(width: 440, height: 480)
        .onChange(of: searchText) { selection = nil }
        .fileImporter(isPresented: $isChoosingFromFinder, allowedContentTypes: [.applicationBundle]) { result in
            if case .success(let url) = result {
                addFromFinder(url)
            }
        }
        .fileDialogDefaultDirectory(URL(fileURLWithPath: "/Applications"))
    }

    private func add(_ bundleID: String?) {
        guard model.canChangeConfig, let bundleID, model.settings(of: bundleID) == nil,
              let entry = catalog.entries.first(where: { $0.bundleID == bundleID })
        else { return }
        model.addApp(bundleID: entry.bundleID, name: entry.name)
        dismiss()
    }

    private func addFromFinder(_ url: URL) {
        guard let bundleID = Bundle(url: url)?.bundleIdentifier, !bundleID.isEmpty else {
            finderError = "This app has no bundle ID."
            return
        }
        model.addApp(bundleID: bundleID, name: AppState.displayName(of: url))
        dismiss()
    }

    private func moveSelection(by offset: Int) {
        let selectable = results.filter { model.settings(of: $0.bundleID) == nil }.map(\.bundleID)
        guard !selectable.isEmpty else { return }
        let next = selection.flatMap(selectable.firstIndex(of:)).map { $0 + offset } ?? (offset > 0 ? 0 : selectable.count - 1)
        selection = selectable[min(max(next, 0), selectable.count - 1)]
    }
}

private struct ResultRow: View {
    let entry: AppCatalog.Entry
    let isAdded: Bool

    var body: some View {
        HStack(spacing: Spacing.small) {
            AppIcon(appURL: entry.url, size: 24)
            Text(verbatim: entry.name)
                .lineLimit(1)
            Spacer()
            if isAdded {
                Text("Added")
                    .foregroundStyle(.secondary)
            }
        }
        .opacity(isAdded ? 0.5 : 1)
    }
}

/// A system search field that has the keyboard focus at once. The arrow keys move the selection of the list,
/// Return adds the selected app, and Escape closes the sheet.
private struct SearchField: NSViewRepresentable {
    @Binding var text: String
    let onMove: (Int) -> Void
    let onSubmit: () -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> FocusedSearchField {
        let field = FocusedSearchField()
        field.delegate = context.coordinator
        field.sendsSearchStringImmediately = true
        field.setAccessibilityIdentifier("searchApps")
        return field
    }

    func updateNSView(_ field: FocusedSearchField, context: Context) {
        context.coordinator.parent = self
        if field.stringValue != text {
            field.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: SearchField

        init(parent: SearchField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.moveDown(_:)): parent.onMove(1)
            case #selector(NSResponder.moveUp(_:)): parent.onMove(-1)
            case #selector(NSResponder.insertNewline(_:)): parent.onSubmit()
            case #selector(NSResponder.cancelOperation(_:)): parent.onCancel()
            default: return false
            }
            return true
        }
    }
}

private final class FocusedSearchField: NSSearchField {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }
}
