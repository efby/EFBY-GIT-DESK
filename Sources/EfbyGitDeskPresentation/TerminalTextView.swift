import AppKit

@MainActor final class TerminalTextView: NSTextView {
    var send: ((String) -> Void)?
    var dimensions: ((Int, Int) -> Void)?
    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) { super.keyDown(with: event); return }
        let escapes: [UInt16: String] = [123: "\u{1b}[D", 124: "\u{1b}[C", 125: "\u{1b}[B", 126: "\u{1b}[A",
                                      115: "\u{1b}[H", 119: "\u{1b}[F", 117: "\u{1b}[3~",
                                      51: "\u{7f}", 36: "\r", 48: "\t", 53: "\u{1b}"]
        if let value = escapes[event.keyCode] { send?(value); return }
        if event.modifierFlags.contains(.control), let first = event.charactersIgnoringModifiers?.utf8.first {
            send?(String(UnicodeScalar(first & 31))); return
        }
        if let text = event.characters { send?(text) }
    }
    override func paste(_ sender: Any?) {
        guard let text = NSPasteboard.general.string(forType: .string) else { return }
        if text.contains("\n") || text.contains("\r") {
            let alert = NSAlert(); alert.messageText = "Pegar varias líneas en el terminal"
            alert.informativeText = String(text.prefix(2_000))
            alert.addButton(withTitle: "Pegar"); alert.addButton(withTitle: "Cancelar")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        send?(text)
    }
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        dimensions?(max(20, Int((newSize.width - 24) / 7.3)), max(5, Int((enclosingScrollView?.contentSize.height ?? 300) / 15)))
    }
}
