import Foundation

public enum BadgeCount {
    private static let groupingMarks: Set<Character> = [",", ".", " ", "\u{00A0}", "\u{202F}", "'"]

    /// Large counts saturate at `Int.max`.
    public static func parse(_ badge: String) -> Int? {
        digits(of: badge).map { Int($0) ?? .max }
    }

    public static func isAbove99(_ badge: String) -> Bool {
        guard let digits = digits(of: badge) else { return false }
        return digits.drop(while: { $0 == "0" }).count > 2
    }

    private static func digits(of badge: String) -> String? {
        let text = badge.hasSuffix("+") ? badge.dropLast() : Substring(badge)
        guard let first = text.first, first.isDigit,
              text.allSatisfy({ $0.isDigit || groupingMarks.contains($0) })
        else { return nil }
        return String(text.filter(\.isDigit))
    }
}

public enum RedBadgeLabel {
    public static let overflow = "99+"
    public static let dot = "•"

    public static func label(for badge: String, fits: (String) -> Bool) -> String {
        if BadgeCount.isAbove99(badge) { return overflow }
        return fits(badge) ? badge : dot
    }
}

private extension Character {
    var isDigit: Bool { ("0"..."9").contains(self) }
}
