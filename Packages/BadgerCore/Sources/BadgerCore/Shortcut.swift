import Foundation

public struct Shortcut: Sendable, Equatable {
    public enum Modifier: String, Sendable, CaseIterable {
        case command
        case control
        case option
        case shift
    }

    public enum ParseError: Error, Sendable, Equatable {
        case unknownKey(String)
        case unknownModifier(String)
        case repeatedModifier(String)
        case missingKey
        case needsCommandOrControl
    }

    public static let keys: Set<String> = {
        let letters = "abcdefghijklmnopqrstuvwxyz".map(String.init)
        let digits = "0123456789".map(String.init)
        let functionKeys = (1...20).map { "f\($0)" }
        let named = [
            "space", "return", "tab", "escape", "delete", "up", "down", "left", "right",
            "home", "end", "pageup", "pagedown",
        ]
        let characters = "-=[];',./\\`".map(String.init)
        return Set(letters + digits + functionKeys + named + characters)
    }()

    public let modifiers: [Modifier]
    public let key: String

    public init(modifiers: Set<Modifier>, key: String) throws {
        guard Self.keys.contains(key) else { throw ParseError.unknownKey(key) }
        guard modifiers.contains(.command) || modifiers.contains(.control) else {
            throw ParseError.needsCommandOrControl
        }
        self.modifiers = Modifier.allCases.filter(modifiers.contains)
        self.key = key
    }

    public init(text: String) throws {
        var parts = text.lowercased().split(separator: "+", omittingEmptySubsequences: false).map(String.init)
        guard let key = parts.popLast(), !key.isEmpty else { throw ParseError.missingKey }
        var modifiers = Set<Modifier>()
        for part in parts {
            guard let modifier = Modifier(rawValue: part) else { throw ParseError.unknownModifier(part) }
            guard modifiers.insert(modifier).inserted else { throw ParseError.repeatedModifier(part) }
        }
        try self.init(modifiers: modifiers, key: key)
    }

    public var text: String {
        (modifiers.map(\.rawValue) + [key]).joined(separator: "+")
    }
}
