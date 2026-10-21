import CoreGraphics

/// All rectangles use the AppKit screen coordinates: the origin at the bottom left of the screen with the menu bar,
/// and y up.
public enum ScreenGeometry {
    public static let alertGap: CGFloat = 6
    public static let arrowOverlap: CGFloat = 10

    /// The index of the screen that holds the largest part of `rect`, or nil when no screen holds a part of it.
    public static func screen(holdingLargestPartOf rect: CGRect, in screens: [CGRect]) -> Int? {
        let areas = screens.map { screen in
            let part = screen.intersection(rect)
            return part.isNull ? 0 : part.width * part.height
        }
        guard let largest = areas.max(), largest > 0 else { return nil }
        return areas.firstIndex(of: largest)
    }

    /// The screen of the item: the screen that holds the item, else the screen that holds its horizontal centre,
    /// else the screen with the menu bar.
    public static func screen(ofItem itemFrame: CGRect, in screens: [CGRect]) -> Int {
        if let index = screen(holdingLargestPartOf: itemFrame, in: screens) { return index }
        let centre = itemFrame.midX
        return screens.firstIndex { $0.minX <= centre && centre < $0.maxX } ?? 0
    }

    /// The Accessibility API gives window frames with the origin at the top left of the screen with the menu bar,
    /// and y down.
    public static func appKitRect(fromAccessibility rect: CGRect, mainScreenHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: mainScreenHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    /// Without a menu bar, the visible frame reaches the top of the screen.
    public static func isMenuBarAutoHidden(screenFrame: CGRect, visibleFrame: CGRect) -> Bool {
        visibleFrame.maxY >= screenFrame.maxY
    }

    /// The panel centres under the item, but stays on the screen. When the item is above the screen (the menu bar
    /// slid away), the panel goes below the top of the screen.
    public static func alertFrame(size: CGSize, itemFrame: CGRect, screenFrame: CGRect) -> CGRect {
        let top = min(itemFrame.minY, screenFrame.maxY) - alertGap
        let centredX = itemFrame.midX - size.width / 2
        let x = min(max(centredX, screenFrame.minX), screenFrame.maxX - size.width)
        return CGRect(x: x, y: top - size.height, width: size.width, height: size.height)
    }

    public static func arrowFrame(size: CGSize, itemFrame: CGRect, menuBarBottom: CGFloat) -> CGRect {
        CGRect(x: itemFrame.midX - size.width / 2, y: menuBarBottom + arrowOverlap - size.height, width: size.width, height: size.height)
    }
}
