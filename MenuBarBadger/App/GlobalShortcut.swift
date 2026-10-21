import BadgerCore
import KeyboardShortcuts
import Observation

extension KeyboardShortcuts.Name {
    static let openSettings = Self("openSettings")
}

/// The config file is the source of truth. KeyboardShortcuts gets each shortcut that the config applies.
final class GlobalShortcut {
    enum Refusal {
        case needsCommandOrControl
        case unknownKey
    }

    private let model: AppModel
    private var observation: Task<Void, Never>?

    init(model: AppModel) {
        self.model = model
    }

    func start(onPress: @escaping () -> Void) {
        KeyboardShortcuts.onKeyDown(for: .openSettings, action: onPress)
        Self.apply(model.config.openSettingsShortcut)
        let model = model
        observation = Task {
            for await shortcut in Observations({ model.config.openSettingsShortcut }) {
                Self.apply(shortcut)
            }
        }
    }

    /// Writes a shortcut that the user recorded to the config file. A refused shortcut puts back the one from the
    /// config file.
    static func record(_ recorded: KeyboardShortcuts.Shortcut?, in model: AppModel) -> Refusal? {
        guard model.canChangeConfig else {
            apply(model.config.openSettingsShortcut)
            return nil
        }
        guard let recorded else {
            model.changeConfig { $0.openSettingsShortcut = nil }
            return nil
        }
        do {
            let shortcut = try BadgerCore.Shortcut(
                carbonKeyCode: recorded.carbonKeyCode, carbonModifiers: recorded.carbonModifiers
            )
            model.changeConfig { $0.openSettingsShortcut = shortcut }
            return nil
        } catch {
            apply(model.config.openSettingsShortcut)
            return error as? BadgerCore.Shortcut.ParseError == .needsCommandOrControl ? .needsCommandOrControl : .unknownKey
        }
    }

    private static func apply(_ shortcut: BadgerCore.Shortcut?) {
        let next = shortcut.map(keyboardShortcut)
        guard KeyboardShortcuts.getShortcut(for: .openSettings) != next else { return }
        KeyboardShortcuts.setShortcut(next, for: .openSettings)
    }

    private static func keyboardShortcut(_ shortcut: BadgerCore.Shortcut) -> KeyboardShortcuts.Shortcut {
        KeyboardShortcuts.Shortcut(carbonKeyCode: shortcut.carbonKeyCode, carbonModifiers: shortcut.carbonModifiers)
    }
}
