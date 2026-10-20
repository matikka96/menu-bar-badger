import Foundation

public enum ConfigCodec {
    public static func decode(_ data: Data) throws(ConfigError) -> Config {
        try checkSyntax(data)
        let file: ConfigFile
        do {
            file = try JSONDecoder().decode(ConfigFile.self, from: data)
        } catch let error as DecodingError {
            throw .invalidValue(describe(error))
        } catch {
            throw .invalidValue(error.localizedDescription)
        }
        guard file.version <= Config.currentVersion else { throw .newerVersion(file.version) }
        return try file.config()
    }

    public static func encode(_ config: Config) -> Data {
        let fields = [
            "  \"version\": \(Config.currentVersion)",
            "  \"apps\": \(encodeApps(config.apps))",
            "  \"badgeStyle\": \(quote(config.badgeStyle.rawValue))",
            "  \"whenNothingNew\": \(quote(config.whenNothingNew.rawValue))",
            "  \"hideWhenNotRunning\": \(config.hideWhenNotRunning)",
            "  \"alertWhenMenuBarHidden\": \(config.alertWhenMenuBarHidden)",
            "  \"openSettingsShortcut\": \(config.openSettingsShortcut.map { quote($0.text) } ?? "null")",
        ]
        return Data("{\n\(fields.joined(separator: ",\n"))\n}\n".utf8)
    }

    private static func encodeApps(_ apps: [MonitoredApp]) -> String {
        guard !apps.isEmpty else { return "[]" }
        let entries = apps.map { app -> String in
            var fields = ["\"bundleID\": \(quote(app.bundleID))"]
            if let name = app.name { fields.append("\"name\": \(quote(name))") }
            fields.append("\"icon\": \(quote(app.icon.rawValue))")
            fields.append("\"arrow\": \(app.arrow)")
            return "    { \(fields.joined(separator: ", ")) }"
        }
        return "[\n\(entries.joined(separator: ",\n"))\n  ]"
    }

    private static func quote(_ text: String) -> String {
        let data = (try? JSONEncoder().encode(text)) ?? Data("\"\"".utf8)
        return String(decoding: data, as: UTF8.self)
    }

    private static func checkSyntax(_ data: Data) throws(ConfigError) {
        do {
            _ = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            let nsError = error as NSError
            let message = nsError.userInfo[NSDebugDescriptionErrorKey] as? String ?? nsError.localizedDescription
            let position = (nsError.userInfo["NSJSONSerializationErrorIndex"] as? Int)
                .map { lineAndColumn(of: $0, in: data) }
            throw .invalidJSON(message: message, line: position?.line, column: position?.column)
        }
    }

    private static func lineAndColumn(of offset: Int, in data: Data) -> (line: Int, column: Int) {
        let prefix = data.prefix(offset)
        let line = prefix.filter { $0 == UInt8(ascii: "\n") }.count + 1
        let lineStart = prefix.lastIndex(of: UInt8(ascii: "\n")).map { $0 + 1 } ?? 0
        return (line, String(decoding: data[lineStart..<min(offset, data.count)], as: UTF8.self).count + 1)
    }

    private static func describe(_ error: DecodingError) -> String {
        switch error {
        case .typeMismatch(_, let context), .valueNotFound(_, let context), .dataCorrupted(let context):
            return located(context.debugDescription, at: context.codingPath)
        case .keyNotFound(let key, let context):
            return located("The key \"\(key.stringValue)\" is missing.", at: context.codingPath)
        @unknown default:
            return error.localizedDescription
        }
    }

    private static func located(_ message: String, at path: [CodingKey]) -> String {
        guard !path.isEmpty else { return message }
        let location = path.map { $0.intValue.map { "[\($0)]" } ?? ".\($0.stringValue)" }.joined()
        return "\(message) (at \(location.hasPrefix(".") ? String(location.dropFirst()) : location))"
    }
}

private struct ConfigFile: Decodable {
    var version: Int
    var apps: [AppEntry]?
    var badgeStyle: BadgeStyle?
    var whenNothingNew: NothingNewMode?
    var hideWhenNotRunning: Bool?
    var alertWhenMenuBarHidden: Bool?
    var openSettingsShortcut: String?

    struct AppEntry: Decodable {
        var bundleID: String
        var name: String?
        var icon: IconMode?
        var arrow: Bool?
    }

    func config() throws(ConfigError) -> Config {
        var seen = Set<String>()
        var apps: [MonitoredApp] = []
        for (index, entry) in (self.apps ?? []).enumerated() {
            guard !entry.bundleID.isEmpty else {
                throw .invalidValue("The bundle ID is empty. (at apps[\(index)].bundleID)")
            }
            guard seen.insert(entry.bundleID).inserted else { continue }
            apps.append(MonitoredApp(
                bundleID: entry.bundleID,
                name: entry.name,
                icon: entry.icon ?? .color,
                arrow: entry.arrow ?? false
            ))
        }
        let shortcut: Shortcut?
        do {
            shortcut = try openSettingsShortcut.map { try Shortcut(text: $0) }
        } catch {
            throw .invalidValue("The shortcut \"\(openSettingsShortcut ?? "")\" is not valid: \(error). (at openSettingsShortcut)")
        }
        return Config(
            apps: apps,
            badgeStyle: badgeStyle ?? .number,
            whenNothingNew: whenNothingNew ?? .show,
            hideWhenNotRunning: hideWhenNotRunning ?? false,
            alertWhenMenuBarHidden: alertWhenMenuBarHidden ?? true,
            openSettingsShortcut: shortcut
        )
    }
}

extension BadgeStyle: Decodable {}
extension NothingNewMode: Decodable {}
extension IconMode: Decodable {}
