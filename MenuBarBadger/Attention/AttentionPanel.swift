import AppKit

/// A transparent panel that never takes the focus from the frontmost app, and shows on all Spaces and over
/// full-screen windows.
class AttentionPanel: NSPanel {
    static let alertLevel = NSWindow.Level.screenSaver
    static let arrowLevel = NSWindow.Level(rawValue: alertLevel.rawValue + 1)

    private static let moveDuration: TimeInterval = 0.2

    private var hiding: Task<Void, Never>?

    init(level: NSWindow.Level, content: NSView) {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        self.level = level
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isReleasedWhenClosed = false
        animationBehavior = .none
        contentView = content
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    var isShown: Bool { isVisible && hiding == nil }

    func show(fadeDuration: TimeInterval) {
        let wasHiding = hiding != nil
        hiding?.cancel()
        hiding = nil
        guard !isVisible || wasHiding || alphaValue < 1 else { return }
        if !isVisible || wasHiding { alphaValue = 0 }
        orderFrontRegardless()
        invalidateShadow()
        animateAlpha(to: 1, duration: fadeDuration)
    }

    func hide(fadeDuration: TimeInterval) {
        hide(duration: fadeDuration) { animateAlpha(to: 0, duration: fadeDuration) }
    }

    func hide(duration: TimeInterval, animation: () -> Void) {
        guard isVisible, hiding == nil else { return }
        guard !Self.reducesMotion, duration > 0 else {
            orderOut(nil)
            return
        }
        animation()
        hiding = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled, let self else { return }
            self.hiding = nil
            self.orderOut(nil)
        }
    }

    func move(to frame: NSRect, isAnimated: Bool) {
        guard isAnimated && !Self.reducesMotion else {
            setFrame(frame, display: false)
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.moveDuration
            animator().setFrame(frame, display: false)
        }
    }

    static var reducesMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private func animateAlpha(to alpha: CGFloat, duration: TimeInterval) {
        guard !Self.reducesMotion else {
            alphaValue = alpha
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            animator().alphaValue = alpha
        }
    }
}
