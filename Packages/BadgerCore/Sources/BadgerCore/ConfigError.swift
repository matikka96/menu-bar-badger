import Foundation

public enum ConfigError: Error, Sendable, Equatable {
    case missing
    case unreadable(String)
    case invalidJSON(message: String, line: Int?, column: Int?)
    case invalidValue(String)
    case newerVersion(Int)
}
