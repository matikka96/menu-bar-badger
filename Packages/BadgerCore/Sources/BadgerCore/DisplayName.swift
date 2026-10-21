import Foundation

public enum DisplayName {
    public static func fromBundleName(_ bundleName: String) -> String {
        bundleName.hasSuffix(".app") ? String(bundleName.dropLast(4)) : bundleName
    }
}
