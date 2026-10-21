import Foundation

/// The Carbon virtual key codes and modifier masks of the US layout, which KeyboardShortcuts uses.
extension Shortcut {
    public enum KeyCodeError: Error, Sendable, Equatable {
        case unknownKeyCode(Int)
    }

    private static let keyCodes: [String: Int] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
        "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17,
        "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29,
        "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "return": 36, "l": 37, "j": 38, "'": 39,
        "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44, "n": 45, "m": 46, ".": 47,
        "tab": 48, "space": 49, "`": 50, "delete": 51, "escape": 53,
        "f17": 64, "f18": 79, "f19": 80, "f20": 90,
        "f5": 96, "f6": 97, "f7": 98, "f3": 99, "f8": 100, "f9": 101, "f11": 103, "f13": 105,
        "f16": 106, "f14": 107, "f10": 109, "f12": 111, "f15": 113,
        "home": 115, "pageup": 116, "f4": 118, "end": 119, "f2": 120, "pagedown": 121, "f1": 122,
        "left": 123, "right": 124, "down": 125, "up": 126,
    ]

    private static let keysByCode = Dictionary(uniqueKeysWithValues: keyCodes.map { ($1, $0) })

    private static let modifierMasks: [(Modifier, Int)] = [
        (.command, 0x100), (.shift, 0x200), (.option, 0x800), (.control, 0x1000),
    ]

    public init(carbonKeyCode: Int, carbonModifiers: Int) throws {
        guard let key = Self.keysByCode[carbonKeyCode] else { throw KeyCodeError.unknownKeyCode(carbonKeyCode) }
        let modifiers = Self.modifierMasks.filter { carbonModifiers & $0.1 != 0 }.map(\.0)
        try self.init(modifiers: Set(modifiers), key: key)
    }

    public var carbonKeyCode: Int {
        // The initializers accept only the keys in `keys`, and each one has a code.
        Self.keyCodes[key]!
    }

    public var carbonModifiers: Int {
        Self.modifierMasks.filter { modifiers.contains($0.0) }.reduce(0) { $0 | $1.1 }
    }
}
