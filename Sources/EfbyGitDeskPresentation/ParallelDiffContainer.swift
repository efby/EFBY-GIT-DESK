import AppKit

@MainActor final class ParallelDiffContainer: NSView {
    private let left = NSScrollView()
    private let right = NSScrollView()
    private var rows: [DiffRow]?
    private var inline: [DiffInlineRow] = []
    private var syntax: DiffSyntax?
    private var synchronizing = false
    private var lastJump: UUID?
    private var blocks: [DiffChangeBlock] = []
    private var lastViewport: DiffViewportStatus?
    var onViewportChange: ((DiffViewportStatus) -> Void)?

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
            let text = NSTextView()
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

    func update(_ newRows: [DiffRow], syntax: DiffSyntax? = nil, blocks: [DiffChangeBlock]? = nil, marks: [DiffMapMark]? = nil, inline: [DiffInlineRow]? = nil) {
        guard rows != newRows || self.syntax != syntax else { return }
        if rows != newRows {
            self.inline = inline ?? DiffIntraline.make(rows: newRows)
            self.blocks = blocks ?? DiffChangeOverview.make(rows: newRows)
            let marks = marks ?? DiffChangeOverview.coloredMap(rows: newRows)
            (left.verticalScroller as? DiffOverviewScroller)?.marks = marks
            (right.verticalScroller as? DiffOverviewScroller)?.marks = marks
        }
        rows = newRows; self.syntax = syntax
        synchronizing = true
        let longest = newRows.reduce(0) { length, row in
            max(length, estimatedColumns(row.before), estimatedColumns(row.after))
        }
        let width = max(400, CGFloat(longest + 10) * 8 + 32)
        render(newRows, in: left, before: true, width: width)
        render(newRows, in: right, before: false, width: width)
        synchronizing = false
        publishViewport()
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
            let hasChange = row.before != row.after && number != nil
            let color: NSColor = hasChange ? (before ? .systemRed : .systemGreen) : NSColor(calibratedWhite: 0.86, alpha: 1)
            let offset = value.length
            value.append(NSAttributedString(string: line + "\n", attributes: [
                .font: font, .foregroundColor: color, .paragraphStyle: paragraph,
                .backgroundColor: hasChange ? color.withAlphaComponent(0.13) : NSColor.clear
            ]))
            let prefixLength = line.utf16.count - content.utf16.count
            if inline.indices.contains(index) {
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
        }
        let selection = text.selectedRanges
        let origin = scroll.contentView.bounds.origin
        text.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        text.textContainer?.containerSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        text.frame = NSRect(x: 0, y: 0, width: width, height: CGFloat(rows.count + 1) * 18 + 24)
        text.textStorage?.setAttributedString(value)
        let validSelection = selection.filter { $0.rangeValue.location + $0.rangeValue.length <= value.length }
        text.selectedRanges = validSelection.isEmpty ? [NSValue(range: NSRange(location: 0, length: 0))] : validSelection
        scroll.contentView.scroll(to: origin)
        scroll.reflectScrolledClipView(scroll.contentView)
    }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window { window.makeFirstResponder(left.documentView) }
    }
    func jump(to target: DiffJumpTarget?) {
        guard let target, lastJump != target.id, let rows, !rows.isEmpty else { return }
        lastJump = target.id
        let row = min(max(0, target.row), rows.count - 1)
        left.contentView.scroll(to: NSPoint(x: left.contentView.bounds.origin.x, y: CGFloat(row) * 18))
        left.reflectScrolledClipView(left.contentView)
    }
    private func estimatedColumns(_ text: String?) -> Int {
        guard let text else { return 0 }
        return text.utf16.count + text.utf16.reduce(0) { $0 + ($1 == 9 ? 3 : 0) }
    }
    override func layout() {
        super.layout()
        left.reflectScrolledClipView(left.contentView)
        right.reflectScrolledClipView(right.contentView)
        publishViewport()
    }
    private func publishViewport() {
        guard let rows, !rows.isEmpty else { return }
        let bounds = left.contentView.bounds
        // AppKit can keep the previous thumb proportion when a document becomes
        // shorter than its viewport. Refresh both tracks from their current frames.
        for scroll in [left, right] {
            let height = scroll.documentView?.frame.height ?? 0
            let visible = scroll.contentView.bounds
            scroll.verticalScroller?.knobProportion = height > 0 ? min(1, visible.height / height) : 1
            scroll.verticalScroller?.doubleValue = height > visible.height ? min(1, max(0, visible.minY / (height - visible.height))) : 0
        }
        let first = min(rows.count - 1, max(0, Int(floor((bounds.minY - 12) / 18))))
        let last = min(rows.count - 1, max(first, Int(ceil((bounds.maxY - 12) / 18)) - 1))
        let status = DiffViewportStatus.make(firstRow: first, lastRow: last, blocks: blocks)
        guard status != lastViewport else { return }
        lastViewport = status; onViewportChange?(status)
    }
    @objc private func boundsChanged(_ notification: Notification) {
        guard !synchronizing, let source = notification.object as? NSClipView else { return }
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
