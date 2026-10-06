import SwiftUI
import AppKit

struct NativeTerminal: NSViewRepresentable {
    let tab: TerminalTab
    let output: String
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true
        let view = TerminalTextView()
        view.isEditable = false; view.isSelectable = true
        view.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        view.backgroundColor = NSColor(red: 0.045, green: 0.055, blue: 0.065, alpha: 1)
        view.textColor = .textColor; view.textContainerInset = NSSize(width: 12, height: 8)
        view.autoresizingMask = [.width]; view.isVerticallyResizable = true
        view.textContainer?.widthTracksTextView = true
        view.isAutomaticLinkDetectionEnabled = false
        view.setAccessibilityLabel("Terminal interactivo del repositorio")
        view.send = { [weak driver = tab.driver] text in driver?.write(text) }
        view.dimensions = { [weak driver = tab.driver] columns, rows in driver?.resize(columns: columns, rows: rows) }
        scroll.documentView = view
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let view = scroll.documentView as? TerminalTextView, view.string != output else { return }
        let wasAtEnd = scroll.contentView.bounds.maxY >= view.bounds.maxY - 30
        view.string = output
        if wasAtEnd { view.scrollToEndOfDocument(nil) }
    }
    static func dismantleNSView(_ scroll: NSScrollView, coordinator: ()) {
        (scroll.documentView as? TerminalTextView)?.send = nil
        (scroll.documentView as? TerminalTextView)?.dimensions = nil
    }
}
