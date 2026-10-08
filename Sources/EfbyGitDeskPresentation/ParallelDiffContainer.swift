import AppKit

@MainActor final class ParallelDiffContainer: NSView {
    private let left = NSScrollView()
    private let right = NSScrollView()
    private var rows: [DiffRow]?
    private var inline: [DiffInlineRow] = []
    private var syntax: DiffSyntax?
    private var callLinks: CodeCallLinks?
    private var synchronizing = false
    private var lastJump: UUID?
    private var pendingJump: DiffJumpTarget?
    private var pinnedOffset: CGPoint?
    private var blocks: [DiffChangeBlock] = []
    private var lastViewport: DiffViewportStatus?
    var onViewportChange: ((DiffViewportStatus) -> Void)?
    var onFollow: ((String, Int, Bool, String, Int, CGFloat, CGFloat) -> Void)?

    init() {
        super.init(frame: .zero)
        appearance = NSAppearance(named: .darkAqua)
        for (scroll, label) in [(left, "Documento 1, versión inferior"), (right, "Documento 2, versión superior")] {
            scroll.translatesAutoresizingMaskIntoConstraints = false
            scroll.hasVerticalScroller = true; scroll.hasHorizontalScroller = true
            scroll.scrollerStyle = .legacy
            scroll.autohidesScrollers = false
            scroll.verticalScroller = DiffOverviewScroller()
            scroll.verticalScroller?.setAccessibilityHelp("Mapa vertical: rojo eliminado, verde agregado. El indicador muestra la posición actual.")
            scroll.borderType = .lineBorder
            let text = DiffTextView()
            text.owner = self
            text.isEditable = false; text.isSelectable = true
            text.isAutomaticLinkDetectionEnabled = false
            text.isHorizontallyResizable = true; text.isVerticallyResizable = true
            text.textContainer?.widthTracksTextView = false
            text.textContainerInset = NSSize(width: 8, height: 12)
            text.backgroundColor = NSColor(red: 0.065, green: 0.075, blue: 0.085, alpha: 1)
            text.setAccessibilityLabel(label)
            scroll.documentView = text
            addSubview(scroll)
            scroll.contentView.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(self, selector: #selector(boundsChanged(_:)),
                name: NSView.boundsDidChangeNotification, object: scroll.contentView)
        }
        NSLayoutConstraint.activate([
            left.leadingAnchor.constraint(equalTo: leadingAnchor), left.topAnchor.constraint(equalTo: topAnchor),
            left.bottomAnchor.constraint(equalTo: bottomAnchor), left.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.5),
            right.leadingAnchor.constraint(equalTo: left.trailingAnchor), right.trailingAnchor.constraint(equalTo: trailingAnchor),
            right.topAnchor.constraint(equalTo: topAnchor), right.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    required init?(coder: NSCoder) { nil }
    isolated deinit { NotificationCenter.default.removeObserver(self) }

    func update(_ newRows: [DiffRow], syntax: DiffSyntax? = nil, blocks: [DiffChangeBlock]? = nil, marks: [DiffMapMark]? = nil, inline: [DiffInlineRow]? = nil, links: CodeCallLinks? = nil) {
        if rows == newRows && self.syntax == syntax {
            guard callLinks != links else { return }
            callLinks = links
            paintLinks(links, rows: newRows)
            finishPosition()
            return
        }
        if rows != newRows {
            self.inline = inline ?? DiffIntraline.make(rows: newRows)
            self.blocks = blocks ?? DiffChangeOverview.make(rows: newRows)
            let marks = marks ?? DiffChangeOverview.coloredMap(rows: newRows)
            (left.verticalScroller as? DiffOverviewScroller)?.marks = marks
            (right.verticalScroller as? DiffOverviewScroller)?.marks = marks
        }
        rows = newRows; self.syntax = syntax; callLinks = links
        synchronizing = true
        let longest = newRows.reduce(0) { length, row in
            max(length, estimatedColumns(row.before), estimatedColumns(row.after))
        }
        let width = max(400, CGFloat(longest + 10) * 8 + 32)
        render(newRows, in: left, before: true, width: width)
        render(newRows, in: right, before: false, width: width)
        synchronizing = false
        refreshScrollerProportions()
        publishViewport()
        finishPosition()
    }
    private func render(_ rows: [DiffRow], in scroll: NSScrollView, before: Bool, width: CGFloat) {
        guard let text = scroll.documentView as? NSTextView else { return }
        let value = NSMutableAttributedString(string: "")
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = 18; paragraph.maximumLineHeight = 18
        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        paragraph.tabStops = []; paragraph.defaultTabInterval = 32
        for (index, row) in rows.enumerated() {
            let number = before ? row.beforeNumber : row.afterNumber
            let content = ((before ? row.before : row.after) ?? "")
                .replacingOccurrences(of: "\r", with: "␍")
                .replacingOccurrences(of: "\u{2028}", with: "↵")
                .replacingOccurrences(of: "\u{2029}", with: "¶")
            let marker = row.changed ? (number == nil ? "·" : (before ? "−" : "+")) : " "
            let line = (number.map { String(format: "%5d", $0) } ?? "     ") + " " + marker + " │ " + content
            let isNewLine = row.before == nil && row.after != nil
            let hasChange = row.before != row.after && number != nil && !isNewLine
            let color: NSColor = hasChange ? (before ? .systemRed : .systemGreen) : NSColor(calibratedWhite: 0.86, alpha: 1)
            let background: NSColor = isNewLine && !before
                ? NSColor.systemGreen.withAlphaComponent(0.13)
                : (hasChange ? color.withAlphaComponent(0.13) : .clear)
            let offset = value.length
            value.append(NSAttributedString(string: line + "\n", attributes: [
                .font: font, .foregroundColor: color, .paragraphStyle: paragraph,
                .backgroundColor: background
            ]))
            let prefixLength = line.utf16.count - content.utf16.count
            if !isNewLine && inline.indices.contains(index) {
                let changes = before ? inline[index].before : inline[index].after
                for change in changes where NSMaxRange(change) <= content.utf16.count {
                    value.addAttribute(.backgroundColor,
                        value: (before ? NSColor.systemRed : NSColor.systemGreen).withAlphaComponent(0.48),
                        range: NSRange(location: offset + prefixLength + change.location, length: change.length))
                }
            }
            let spans = before ? syntax?.before : syntax?.after
            if let spans, spans.indices.contains(index) {
                for token in spans[index] where token.range.location + token.range.length <= content.utf16.count {
                    value.addAttribute(.foregroundColor, value: token.kind.color,
                        range: NSRange(location: offset + prefixLength + token.range.location, length: token.range.length))
                }
            }
            let rowLinks = before ? nil : callLinks?.after
            if let rowLinks, rowLinks.indices.contains(index) {
                for link in rowLinks[index] where NSMaxRange(link.range) <= content.utf16.count {
                    guard let url = CodeCallIndex.url(for: link) else { continue }
                    let painted = NSRange(location: offset + prefixLength + link.range.location, length: link.range.length)
                    value.addAttributes([
                        .callTarget: url,
                        .underlineStyle: NSUnderlineStyle.single.rawValue,
                        .toolTip: "Ir a \(link.name) en \(link.path), línea \(link.line)"
                    ], range: painted)
                }
            }
        }
        let selection = text.selectedRanges
        let origin = pinnedOffset.map { NSPoint(x: max(0, $0.x), y: max(0, $0.y)) } ?? scroll.contentView.bounds.origin
        text.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        text.textContainer?.containerSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        text.frame = NSRect(x: 0, y: 0, width: width, height: CGFloat(rows.count + 1) * 18 + 24)
        text.textStorage?.setAttributedString(value)
        let validSelection = selection.filter { $0.rangeValue.location + $0.rangeValue.length <= value.length }
        text.selectedRanges = validSelection.isEmpty ? [NSValue(range: NSRange(location: 0, length: 0))] : validSelection
        scroll.contentView.scroll(to: origin)
        scroll.reflectScrolledClipView(scroll.contentView)
    }
    private func paintLinks(_ links: CodeCallLinks?, rows: [DiffRow]) {
        paint(nil, rows: rows, before: true, in: left)
        paint(links?.after, rows: rows, before: false, in: right)
    }
    private func paint(_ rowLinks: [[CodeCallLink]]?, rows: [DiffRow], before: Bool, in scroll: NSScrollView) {
        guard let text = scroll.documentView as? NSTextView, let storage = text.textStorage else { return }
        var existing: [NSRange] = []
        storage.enumerateAttribute(.callTarget, in: NSRange(location: 0, length: storage.length)) { value, range, _ in
            if value != nil { existing.append(range) }
        }
        storage.beginEditing()
        for range in existing {
            storage.removeAttribute(.callTarget, range: range)
            storage.removeAttribute(.underlineStyle, range: range)
            storage.removeAttribute(.toolTip, range: range)
        }
        var offset = 0
        for (index, row) in rows.enumerated() {
            let number = before ? row.beforeNumber : row.afterNumber
            let content = ((before ? row.before : row.after) ?? "")
                .replacingOccurrences(of: "\r", with: "␍")
                .replacingOccurrences(of: "\u{2028}", with: "↵")
                .replacingOccurrences(of: "\u{2029}", with: "¶")
            let marker = row.changed ? (number == nil ? "·" : (before ? "−" : "+")) : " "
            let line = (number.map { String(format: "%5d", $0) } ?? "     ") + " " + marker + " │ " + content
            let prefix = line.utf16.count - content.utf16.count
            if let rowLinks, rowLinks.indices.contains(index) {
                for link in rowLinks[index] where NSMaxRange(link.range) <= content.utf16.count {
                    guard let url = CodeCallIndex.url(for: link) else { continue }
                    let painted = NSRange(location: offset + prefix + link.range.location, length: link.range.length)
                    guard NSMaxRange(painted) <= storage.length else { continue }
                    storage.addAttributes([
                        .callTarget: url,
                        .underlineStyle: NSUnderlineStyle.single.rawValue,
                        .toolTip: "Ir a \(link.name) en \(link.path), línea \(link.line)"
                    ], range: painted)
                }
            }
            offset += line.utf16.count + 1
        }
        storage.endEditing()
    }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window { window.makeFirstResponder(left.documentView) }
    }
    func jump(to target: DiffJumpTarget?) {
        guard let target, lastJump != target.id else { return }
        lastJump = target.id
        if let offset = target.restoreOffset {
            pendingJump = nil
            pinnedOffset = offset
            applyPinnedOffset()
        } else {
            pinnedOffset = nil
            pendingJump = target
            revealPendingJump()
        }
    }
    private func revealPendingJump() {
        guard let target = pendingJump, let rows, !rows.isEmpty else { return }
        let row = min(max(0, target.row), rows.count - 1)
        let visible = left.contentView.bounds
        let documentHeight = left.documentView?.frame.height ?? 0
        guard visible.height > 1, documentHeight > 1 else { return }
        let maxY = max(0, documentHeight - visible.height)
        synchronizing = true
        for scroll in [left, right] {
            let x = target.restoreOffset.map { max(0, $0.x) } ?? scroll.contentView.bounds.origin.x
            let y = target.restoreOffset.map { min(max(0, $0.y), maxY) } ?? min(CGFloat(row) * 18, maxY)
            scroll.contentView.scroll(to: NSPoint(x: x, y: y))
            scroll.reflectScrolledClipView(scroll.contentView)
        }
        synchronizing = false
        pendingJump = nil
        publishViewport()
    }
    private func finishPosition() {
        if pinnedOffset != nil { applyPinnedOffset() }
        else { revealPendingJump() }
    }
    private func applyPinnedOffset() {
        guard let pinned = pinnedOffset else { return }
        let documentHeight = left.documentView?.frame.height ?? 0
        let visibleHeight = left.contentView.bounds.height
        guard visibleHeight > 1, documentHeight > 1 else { return }
        let maxY = max(0, documentHeight - visibleHeight)
        let y = min(max(0, pinned.y), maxY)
        let x = max(0, pinned.x)
        let current = left.contentView.bounds.origin
        if abs(current.y - y) < 1, abs(current.x - x) < 1,
           abs(right.contentView.bounds.origin.y - y) < 1 { return }
        synchronizing = true
        for scroll in [left, right] {
            scroll.contentView.scroll(to: NSPoint(x: x, y: y))
            scroll.reflectScrolledClipView(scroll.contentView)
        }
        synchronizing = false
        publishViewport()
    }
    private func estimatedColumns(_ text: String?) -> Int {
        guard let text else { return 0 }
        return text.utf16.count + text.utf16.reduce(0) { $0 + ($1 == 9 ? 3 : 0) }
    }
    override func layout() {
        super.layout()
        if pinnedOffset != nil { applyPinnedOffset() }
        else if pendingJump != nil { revealPendingJump() }
        else { publishViewport() }
    }
    private func refreshScrollerProportions() {
        for scroll in [left, right] {
            let height = scroll.documentView?.frame.height ?? 0
            let visible = scroll.contentView.bounds.height
            guard height > 0, visible > 0 else { continue }
            scroll.verticalScroller?.knobProportion = min(1, visible / height)
        }
    }
    private func publishViewport() {
        guard let rows, !rows.isEmpty else { return }
        let bounds = left.contentView.bounds
        let first = min(rows.count - 1, max(0, Int(floor((bounds.minY - 12) / 18))))
        let last = min(rows.count - 1, max(first, Int(ceil((bounds.maxY - 12) / 18)) - 1))
        let status = DiffViewportStatus.make(firstRow: first, lastRow: last, blocks: blocks)
        guard status != lastViewport else { return }
        lastViewport = status; onViewportChange?(status)
    }
    @objc private func boundsChanged(_ notification: Notification) {
        guard !synchronizing, let source = notification.object as? NSClipView else { return }
        if let pinned = pinnedOffset,
           abs(source.bounds.origin.y - pinned.y) > 2 || abs(source.bounds.origin.x - pinned.x) > 2 {
            pinnedOffset = nil
        }
        let target = source === left.contentView ? right : left
        let origin = source.bounds.origin
        defer { publishViewport() }
        guard abs(target.contentView.bounds.origin.y - origin.y) > 0.5 ||
              abs(target.contentView.bounds.origin.x - origin.x) > 0.5 else { return }
        synchronizing = true
        target.contentView.scroll(to: origin)
        target.reflectScrolledClipView(target.contentView)
        synchronizing = false
    }
}

extension NSAttributedString.Key {
    static let callTarget = NSAttributedString.Key("efbyCallTarget")
}

final class DiffTextView: NSTextView {
    weak var owner: ParallelDiffContainer?
    private var linkTracking: NSTrackingArea?
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let linkTracking { removeTrackingArea(linkTracking) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseMoved, .cursorUpdate, .activeInKeyWindow, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        linkTracking = area
    }
    override func cursorUpdate(with event: NSEvent) {
        if link(at: event) != nil { NSCursor.pointingHand.set() }
        else { super.cursorUpdate(with: event) }
    }
    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        if link(at: event) != nil { NSCursor.pointingHand.set() }
    }
    private func link(at event: NSEvent) -> Any? {
        guard let layoutManager, let container = textContainer else { return nil }
        let point = convert(event.locationInWindow, from: nil)
        let location = NSPoint(x: point.x - textContainerInset.width, y: point.y - textContainerInset.height)
        var fraction: CGFloat = 0
        let index = layoutManager.characterIndex(for: location, in: container, fractionOfDistanceBetweenInsertionPoints: &fraction)
        guard fraction < 1, let storage = textStorage, index < storage.length else { return nil }
        return storage.attribute(.callTarget, at: index, effectiveRange: nil)
    }
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let index = characterIndexForInsertion(at: point)
        if let storage = textStorage, index < storage.length,
           let link = storage.attribute(.callTarget, at: index, effectiveRange: nil) {
            owner?.follow(link, from: self)
            return
        }
        super.mouseDown(with: event)
    }
}

extension ParallelDiffContainer {
    func follow(_ link: Any, from text: NSTextView) {
        guard let target = CodeCallIndex.target(from: link) else { return }
        let origin = (text.enclosingScrollView ?? right).contentView.bounds.origin
        onFollow?(target.fileID, target.line, target.before, target.name, target.callLine, origin.x, origin.y)
    }
}
