import Foundation
import Testing
@testable import BadgerCore

struct ConfigCodecTests {
    private func decode(_ json: String) throws(ConfigError) -> Config {
        try ConfigCodec.decode(Data(json.utf8))
    }

    private func error(for json: String) -> ConfigError? {
        do {
            _ = try decode(json)
            return nil
        } catch {
            return error
        }
    }

    @Test func minimalFileGivesTheDefaults() throws {
        let config = try decode(#"{"version": 1}"#)
        #expect(config == Config())
        #expect(config.apps.isEmpty)
        #expect(config.badgeStyle == .number)
        #expect(config.whenNothingNew == .show)
        #expect(config.hideWhenNotRunning == false)
        #expect(config.alertWhenMenuBarHidden == true)
        #expect(config.openSettingsShortcut == nil)
    }

    @Test func appDefaultsAndUnknownFields() throws {
        let config = try decode(#"{"version": 1, "extra": 5, "apps": [{"bundleID": "com.apple.mail", "x": 1}]}"#)
        #expect(config.apps == [MonitoredApp(bundleID: "com.apple.mail")])
    }

    @Test func firstDuplicateWins() throws {
        let config = try decode("""
        {"version": 1, "apps": [
          {"bundleID": "a", "icon": "monochrome"},
          {"bundleID": "b"},
          {"bundleID": "a", "arrow": true}
        ]}
        """)
        #expect(config.apps.map(\.bundleID) == ["a", "b"])
        #expect(config.apps[0].icon == .monochrome)
        #expect(config.apps[0].arrow == false)
    }

    @Test func newerVersionIsAnError() {
        #expect(error(for: #"{"version": 2}"#) == .newerVersion(2))
    }

    @Test func badJSONReportsTheLine() {
        guard case .invalidJSON(_, let line, let column) = error(for: "{\n  \"version\": 1,\n  oops\n}") else {
            Issue.record("expected invalidJSON")
            return
        }
        #expect(line == 3)
        #expect(column != nil)
    }

    @Test(arguments: [
        #"{"apps": []}"#,
        #"{"version": "1"}"#,
        #"{"version": 1, "apps": {}}"#,
        #"{"version": 1, "apps": [{"name": "Mail"}]}"#,
        #"{"version": 1, "apps": [{"bundleID": ""}]}"#,
        #"{"version": 1, "apps": [{"bundleID": "a", "icon": "sepia"}]}"#,
        #"{"version": 1, "badgeStyle": "huge"}"#,
        #"{"version": 1, "whenNothingNew": 3}"#,
        #"{"version": 1, "hideWhenNotRunning": 1}"#,
        #"{"version": 1, "openSettingsShortcut": "shift+b"}"#,
        #"{"version": 1, "openSettingsShortcut": 5}"#,
    ])
    func wrongValueIsAnError(json: String) {
        guard case .invalidValue = error(for: json) else {
            Issue.record("expected invalidValue for \(json)")
            return
        }
    }

    @Test func oneWrongValueRejectsTheWholeFile() {
        #expect(error(for: #"{"version": 1, "badgeStyle": "redBadge", "whenNothingNew": "nope"}"#) != nil)
    }

    @Test func roundTripKeepsTheConfigAndTheFieldOrder() throws {
        let config = Config(
            apps: [
                MonitoredApp(bundleID: "com.apple.mail", name: "Mail"),
                MonitoredApp(bundleID: "com.tinyspeck.slackmacgap", name: "Slack", icon: .monochrome, arrow: true),
            ],
            badgeStyle: .redBadge,
            whenNothingNew: .dim,
            hideWhenNotRunning: true,
            alertWhenMenuBarHidden: false,
            openSettingsShortcut: try Shortcut(text: "shift+command+b")
        )
        let data = ConfigCodec.encode(config)
        #expect(try ConfigCodec.decode(data) == config)
        #expect(ConfigCodec.encode(try ConfigCodec.decode(data)) == data)

        let text = String(decoding: data, as: UTF8.self)
        let order = ["version", "apps", "badgeStyle", "whenNothingNew", "hideWhenNotRunning",
                     "alertWhenMenuBarHidden", "openSettingsShortcut"]
        let positions = order.map { text.range(of: "\"\($0)\"")!.lowerBound }
        #expect(positions == positions.sorted())
        #expect(text.contains("\"openSettingsShortcut\": \"command+shift+b\""))
    }

    @Test func defaultFileMatchesTheSpecExample() {
        let text = String(decoding: ConfigCodec.encode(Config()), as: UTF8.self)
        #expect(text == """
        {
          "version": 1,
          "apps": [],
          "badgeStyle": "number",
          "whenNothingNew": "show",
          "hideWhenNotRunning": false,
          "alertWhenMenuBarHidden": true,
          "openSettingsShortcut": null
        }

        """)
    }
}
