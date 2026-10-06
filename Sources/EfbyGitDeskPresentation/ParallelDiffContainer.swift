import AppKit

@MainActor final class ParallelDiffContainer: NSView {
    private let left = NSScrollView()
    private let right = NSScrollView()
    private var rows: [DiffRow]?
    private var synchronizing = false

    init() {
        super.init(frame: .zero)
        appearance = NSAppearance(named: .darkAqua)
        for (scroll, label) in [(left, "Documento 1, versión inferior"), (right, "Documento 2, versión superior")] {
            scroll.translatesAutoresizingMaskIntoConstraints = false
            scroll.hasVerticalScroller = true; scroll.hasHorizontalScroller = true
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

    func update(_ newRows: [DiffRow]) {
        guard rows != newRows else { return }
        rows = newRows
        synchronizing = true
        render(newRows, in: left, before: true)
        render(newRows, in: right, before: false)
        synchronizing = false
    }
    private func render(_ rows: [DiffRow], in scroll: NSScrollView, before: Bool) {
        guard let text = scroll.documentView as? NSTextView else { return }
        let value = NSMutableAttributedString(string: "")
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = 18; paragraph.maximumLineHeight = 18
        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        var longest = 0
        for row in rows {
            let number = before ? row.beforeNumber : row.afterNumber
            let content = ((before ? row.before : row.after) ?? "")
                .replacingOccurrences(of: "\r", with: "␍")
                .replacingOccurrences(of: "\u{2028}", with: "↵")
                .replacingOccurrences(of: "\u{2029}", with: "¶")
            let marker = row.changed ? (number == nil ? "·" : (before ? "−" : "+")) : " "
            let line = (number.map { String(format: "%5d", $0) } ?? "     ") + " " + marker + " │ " + content
            longest = max(longest, line.utf16.count)
            let color: NSColor = row.changed ? (before ? .systemRed : .systemGreen) : NSColor(calibratedWhite: 0.86, alpha: 1)
            value.append(NSAttributedString(string: line + "\n", attributes: [
                .font: font, .foregroundColor: color, .paragraphStyle: paragraph,
                .backgroundColor: row.changed ? color.withAlphaComponent(0.13) : NSColor.clear
            ]))
        }
        let width = max(400, CGFloat(longest) * 8 + 32)
        text.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        text.textContainer?.containerSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        text.frame = NSRect(x: 0, y: 0, width: width, height: CGFloat(rows.count + 1) * 18 + 24)
        text.textStorage?.setAttributedString(value)
    }
    @objc private func boundsChanged(_ notification: Notification) {
        guard !synchronizing, let source = notification.object as? NSClipView else { return }
        let target = source === left.contentView ? right : left
        guard abs(target.contentView.bounds.origin.y - source.bounds.origin.y) > 0.5 else { return }
        synchronizing = true
        target.contentView.scroll(to: NSPoint(x: target.contentView.bounds.origin.x, y: source.bounds.origin.y))
        target.reflectScrolledClipView(target.contentView)
        synchronizing = false
    }
}
