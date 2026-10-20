import Testing
@testable import BadgerCore

struct ShortcutTests {
    @Test(arguments: Shortcut.Modifier.allCases)
    func roundTripForEachModifier(modifier: Shortcut.Modifier) throws {
        let withCommand = modifier == .command ? "command+b" : "command+\(modifier.rawValue)+b"
        let shortcut = try Shortcut(text: withCommand)
        #expect(try Shortcut(text: shortcut.text) == shortcut)
        #expect(shortcut.modifiers.contains(modifier))
    }

    @Test(arguments: ["a", "7", "f20", "space", "pagedown", "-", "\\", "`"])
    func roundTripForEachKeyKind(key: String) throws {
        let shortcut = try Shortcut(text: "control+\(key)")
        #expect(shortcut.key == key)
        #expect(shortcut.text == "control+\(key)")
    }

    @Test func writeOrderIsFixedAndReadOrderIsFree() throws {
        let shortcut = try Shortcut(text: "Shift+Option+Control+Command+B")
        #expect(shortcut.text == "command+control+option+shift+b")
    }

    @Test func errors() {
        #expect(throws: Shortcut.ParseError.unknownKey("f21")) { try Shortcut(text: "command+f21") }
        #expect(throws: Shortcut.ParseError.repeatedModifier("shift")) { try Shortcut(text: "command+shift+shift+b") }
        #expect(throws: Shortcut.ParseError.needsCommandOrControl) { try Shortcut(text: "option+shift+b") }
        #expect(throws: Shortcut.ParseError.unknownModifier("fn")) { try Shortcut(text: "fn+command+b") }
        #expect(throws: Shortcut.ParseError.missingKey) { try Shortcut(text: "command+") }
    }
}
