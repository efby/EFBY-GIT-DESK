import AppKit

/// Prevent a hidden terminal/search field from retaining keyboard input.
@MainActor final class ComparisonFocusView: NSView {
    private weak var previousResponder: NSResponder?
    private weak var sourceWindow: NSWindow?
    override var acceptsFirstResponder: Bool { true }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window, sourceWindow == nil else { return }
        sourceWindow = window; previousResponder = window.firstResponder
        window.makeFirstResponder(self)
    }
    func restoreFocus() {
        guard let sourceWindow, sourceWindow.isVisible else { return }
        if let previousResponder, let view = previousResponder as? NSView, view.window === sourceWindow {
            sourceWindow.makeFirstResponder(previousResponder)
        } else {
            sourceWindow.makeFirstResponder(nil)
        }
    }
}
