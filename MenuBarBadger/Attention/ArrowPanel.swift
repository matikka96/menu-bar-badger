import AppKit
import SwiftUI

final class ArrowPanel: AttentionPanel {
    static let size = CGSize(width: 42, height: 42)
    private static let fadeDuration: TimeInterval = 0.2
    private static let flyAwayDuration: TimeInterval = 0.3
    private static let flightFrameInterval: Duration = .milliseconds(8)
    private static let underMenuBarLevel = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue - 1)
    private static let firstShowBounces = 3

    private let bounce = ArrowBounce()
    private var flight: Task<Void, Never>?

    init() {
        let hosting = NSHostingView(rootView: ArrowContent(bounce: bounce))
        super.init(level: Self.arrowLevel, content: hosting)
        ignoresMouseEvents = true
        setContentSize(Self.size)
    }

    // AppKit keeps a window below the menu bar level out of the menu bar, which stops the flight.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    func showOrBounce() {
        let isFirstShow = !isShown
        flight?.cancel()
        flight = nil
        level = Self.arrowLevel
        show(fadeDuration: Self.fadeDuration)
        guard !Self.reducesMotion else { return }
        bounce.repeats = isFirstShow ? Self.firstShowBounces : 1
        bounce.trigger += 1
    }

    func flyAway() {
        hide(duration: Self.flyAwayDuration) {
            level = Self.underMenuBarLevel
            let start = frame
            let rise = (screen?.frame.maxY ?? frame.maxY) - start.minY
            // A frame animation through animator() jumps to its end after the level change.
            flight = Task { [weak self] in
                let clock = ContinuousClock()
                let begin = clock.now
                var progress = 0.0
                while progress < 1, !Task.isCancelled {
                    try? await Task.sleep(for: Self.flightFrameInterval)
                    guard !Task.isCancelled, let self else { return }
                    progress = min(1, (clock.now - begin) / .seconds(Self.flyAwayDuration))
                    setFrame(start.offsetBy(dx: 0, dy: rise * progress * progress), display: false)
                }
            }
        }
    }
}

@Observable
private final class ArrowBounce {
    var repeats = 1
    var trigger = 0
}

private struct ArrowContent: View {
    let bounce: ArrowBounce

    var body: some View {
        Image(systemName: "arrow.up")
            .font(.system(size: 33, weight: .bold))
            .foregroundStyle(.red)
            .symbolEffect(.bounce.up, options: .repeat(bounce.repeats), value: bounce.trigger)
            .frame(width: ArrowPanel.size.width, height: ArrowPanel.size.height)
            .accessibilityHidden(true)
    }
}
