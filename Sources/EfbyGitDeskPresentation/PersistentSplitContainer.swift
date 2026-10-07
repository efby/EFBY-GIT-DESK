import AppKit

@MainActor final class PersistentSplitContainer: NSSplitView, NSSplitViewDelegate {
    var anchoredLeading = true
    var minimum: Double = 210
    var maximum: Double = 340
    var otherMinimum: Double = 370
    var preferredWidth: Double = 340
    var changed: ((Double) -> Void)?
    private var applying = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isVertical = true; dividerStyle = .thin; delegate = self
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func resizeSubviews(withOldSize oldSize: NSSize) { applyPreferredWidth() }

    /// Window resizing may constrain the panel without overwriting the user's choice.
    func applyPreferredWidth() {
        guard !applying, arrangedSubviews.count == 2, bounds.width > dividerThickness else { return }
        applying = true
        defer { applying = false }
        let available = bounds.width - dividerThickness
        let upper = min(maximum, max(0, available - otherMinimum))
        let lower = min(minimum, upper)
        let actual = min(upper, max(lower, preferredWidth))
        let leading = anchoredLeading ? actual : available - actual
        arrangedSubviews[0].frame = NSRect(x: 0, y: 0, width: leading, height: bounds.height)
        arrangedSubviews[1].frame = NSRect(x: leading + dividerThickness, y: 0, width: available - leading, height: bounds.height)
        needsDisplay = true
    }
    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        let available = max(0, bounds.width - dividerThickness)
        return anchoredLeading ? min(minimum, max(0, available - otherMinimum)) : max(otherMinimum, available - maximum)
    }
    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        let available = max(0, bounds.width - dividerThickness)
        return anchoredLeading ? min(maximum, max(0, available - otherMinimum)) : max(otherMinimum, available - minimum)
    }
    func splitView(_ splitView: NSSplitView, canCollapseSubview subview: NSView) -> Bool { false }
    func splitViewDidResizeSubviews(_ notification: Notification) {
        guard !applying, arrangedSubviews.count == 2 else { return }
        // Only divider interaction saves a new preference, never initial/window layout.
        guard let type = window?.currentEvent?.type, type == .leftMouseDragged || type == .leftMouseUp else { return }
        rememberDividerWidth()
    }
    func rememberDividerWidth() {
        guard arrangedSubviews.count == 2 else { return }
        let actual = arrangedSubviews[anchoredLeading ? 0 : 1].frame.width
        guard actual.isFinite, actual >= minimum, actual <= maximum, abs(actual - preferredWidth) > 0.5 else { return }
        preferredWidth = actual
        // Defer state publication beyond AppKit's current layout pass.
        Task { @MainActor [weak self] in self?.changed?(actual) }
    }
}
