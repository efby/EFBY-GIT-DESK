import AppKit

/// The change overview sits in the native vertical track, behind its draggable thumb.
@MainActor final class DiffOverviewScroller: NSScroller {
    var marks: [DiffMapMark] = [] { didSet { needsDisplay = true } }
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let slot = rect(for: .knobSlot)
        guard !marks.isEmpty, slot.height > 0 else { return }
        let step = slot.height / CGFloat(marks.count)
        for (index, mark) in marks.enumerated() where mark.removed || mark.added {
            let height = min(slot.height, max(2, step))
            let offset = min(slot.height - height, CGFloat(index) * step)
            let y = isFlipped ? slot.minY + offset : slot.maxY - offset - height
            if mark.removed {
                NSColor.systemRed.setFill()
                NSRect(x: slot.minX, y: y, width: slot.width / 2, height: height).fill()
            }
            if mark.added {
                NSColor.systemGreen.setFill()
                NSRect(x: slot.midX, y: y, width: slot.width / 2, height: height).fill()
            }
        }
        drawKnob() // Keep the standard current-position indicator above the map.
    }
}
