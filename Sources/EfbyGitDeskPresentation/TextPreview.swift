import SwiftUI
import AppKit

struct TextPreview: NSViewRepresentable {
    let text: String
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true; scroll.hasHorizontalScroller = true
        let view = NSTextView()
        view.isEditable = false; view.isSelectable = true
        view.isAutomaticLinkDetectionEnabled = false
        view.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        view.backgroundColor = NSColor(red: 0.065, green: 0.075, blue: 0.085, alpha: 1)
        view.textColor = .textColor; view.textContainerInset = NSSize(width: 12, height: 12)
        view.isHorizontallyResizable = true; view.isVerticallyResizable = true
        view.autoresizingMask = [.width]
        view.textContainer?.widthTracksTextView = false
        view.textContainer?.containerSize = NSSize(width: 20_000, height: CGFloat.greatestFiniteMagnitude)
        view.setAccessibilityLabel("Diferencias de archivo")
        scroll.documentView = view
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let view = scroll.documentView as? NSTextView, view.string != text else { return }
        let value = NSMutableAttributedString(string: "")
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let color: NSColor = line.hasPrefix("+") ? .systemGreen : (line.hasPrefix("-") ? .systemRed : (line.hasPrefix("@@") ? .systemTeal : .textColor))
            value.append(NSAttributedString(string: String(line) + "\n", attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular), .foregroundColor: color
            ]))
        }
        view.textStorage?.setAttributedString(value)
    }
}
