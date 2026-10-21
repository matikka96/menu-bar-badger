import CoreGraphics
import Testing
@testable import BadgerCore

struct ScreenGeometryTests {
    /// A notched built-in screen with the menu bar, and a taller external screen to its right with its top higher.
    private static let notched = CGRect(x: 0, y: 0, width: 1512, height: 982)
    private static let tallerAtTheSide = CGRect(x: 1512, y: -200, width: 1440, height: 2560)
    private static let above = CGRect(x: 0, y: 982, width: 1920, height: 1080)

    @Test func fullScreenWindowUnderTheNotch() {
        let window = ScreenGeometry.appKitRect(fromAccessibility: CGRect(x: 0, y: 38, width: 1512, height: 944), mainScreenHeight: 982)
        #expect(window == CGRect(x: 0, y: 0, width: 1512, height: 944))
        #expect(ScreenGeometry.screen(holdingLargestPartOf: window, in: [Self.notched, Self.tallerAtTheSide]) == 0)
    }

    @Test func windowOnATallerScreenAtTheSide() {
        let window = ScreenGeometry.appKitRect(fromAccessibility: CGRect(x: 1512, y: -1378, width: 1440, height: 2560), mainScreenHeight: 982)
        #expect(window == Self.tallerAtTheSide)
        #expect(ScreenGeometry.screen(holdingLargestPartOf: window, in: [Self.notched, Self.tallerAtTheSide]) == 1)
    }

    @Test func windowOnAScreenAbove() {
        let window = CGRect(x: 100, y: 1000, width: 800, height: 600)
        #expect(ScreenGeometry.screen(holdingLargestPartOf: window, in: [Self.notched, Self.above]) == 1)
    }

    @Test func windowAcrossTwoScreensBelongsToTheLargerPart() {
        let mostlyRight = CGRect(x: 1312, y: 100, width: 800, height: 600)
        let mostlyLeft = CGRect(x: 1012, y: 100, width: 800, height: 600)
        #expect(ScreenGeometry.screen(holdingLargestPartOf: mostlyRight, in: [Self.notched, Self.tallerAtTheSide]) == 1)
        #expect(ScreenGeometry.screen(holdingLargestPartOf: mostlyLeft, in: [Self.notched, Self.tallerAtTheSide]) == 0)
    }

    @Test func windowOnNoScreen() {
        let window = CGRect(x: -5000, y: 0, width: 800, height: 600)
        #expect(ScreenGeometry.screen(holdingLargestPartOf: window, in: [Self.notched, Self.tallerAtTheSide]) == nil)
    }

    @Test func itemAboveTheScreenUsesItsHorizontalCentre() {
        let slidAway = CGRect(x: 1700, y: 2400, width: 30, height: 24)
        #expect(ScreenGeometry.screen(ofItem: slidAway, in: [Self.notched, Self.tallerAtTheSide]) == 1)
        let nowhere = CGRect(x: -500, y: 5000, width: 30, height: 24)
        #expect(ScreenGeometry.screen(ofItem: nowhere, in: [Self.notched, Self.tallerAtTheSide]) == 0)
    }

    @Test func menuBarAutoHide() {
        #expect(ScreenGeometry.isMenuBarAutoHidden(screenFrame: Self.notched, visibleFrame: CGRect(x: 0, y: 70, width: 1512, height: 912)))
        #expect(!ScreenGeometry.isMenuBarAutoHidden(screenFrame: Self.notched, visibleFrame: CGRect(x: 0, y: 70, width: 1512, height: 875)))
    }

    @Test func alertCentresUnderTheItem() {
        let item = CGRect(x: 700, y: 945, width: 40, height: 37)
        let frame = ScreenGeometry.alertFrame(size: CGSize(width: 80, height: 36), itemFrame: item, screenFrame: Self.notched)
        #expect(frame == CGRect(x: 680, y: 903, width: 80, height: 36))
    }

    @Test func alertStaysOnTheScreenOfTheItem() {
        let size = CGSize(width: 80, height: 36)
        let nearRightEdge = CGRect(x: 1490, y: 945, width: 22, height: 37)
        #expect(ScreenGeometry.alertFrame(size: size, itemFrame: nearRightEdge, screenFrame: Self.notched).maxX == 1512)
        let nearLeftEdgeOfTheSecondScreen = CGRect(x: 1515, y: 2336, width: 22, height: 24)
        #expect(ScreenGeometry.alertFrame(size: size, itemFrame: nearLeftEdgeOfTheSecondScreen, screenFrame: Self.tallerAtTheSide).minX == 1512)
    }

    @Test func alertGoesBelowTheTopOfTheScreenWhenTheItemSlidAway() {
        let slidAway = CGRect(x: 700, y: 990, width: 40, height: 37)
        let frame = ScreenGeometry.alertFrame(size: CGSize(width: 80, height: 36), itemFrame: slidAway, screenFrame: Self.notched)
        #expect(frame.maxY == 976)
    }

    @Test func arrowCentresUnderTheMenuBar() {
        let item = CGRect(x: 700, y: 945, width: 41, height: 37)
        let frame = ScreenGeometry.arrowFrame(size: CGSize(width: 42, height: 42), itemFrame: item, menuBarBottom: 945)
        #expect(frame.midX == item.midX)
        #expect(frame.maxY == 955)
    }
}
