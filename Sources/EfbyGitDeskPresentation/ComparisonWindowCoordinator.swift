import SwiftUI
import EfbyGitDeskDomain

@MainActor final class ComparisonWindowCoordinator: NSObject, NSWindowDelegate {
    private let model: DeskModel
    private weak var sourceWindow: NSWindow?
    private(set) var window: NSWindow?
    private var dismissing = false
    private let showWindow: Bool

    init(model: DeskModel, showWindow: Bool = true) { self.model = model; self.showWindow = showWindow }
    func update(file: FileChange?, source: NSWindow?) {
        if let source { sourceWindow = source }
        guard let file else { dismiss(); return }
        if let hosting = window?.contentView as? NSHostingView<FileDiffView> {
            hosting.rootView = FileDiffView(model: model, file: file)
            window?.title = "Comparar · " + file.name
            return
        }
        guard !showWindow || sourceWindow?.isKeyWindow == true else { return }
        let frame = sourceWindow?.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let comparisonWindow = NSWindow(contentRect: frame, styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        comparisonWindow.isReleasedWhenClosed = false
        comparisonWindow.title = "Comparar · " + file.name
        comparisonWindow.appearance = NSAppearance(named: .darkAqua)
        comparisonWindow.collectionBehavior = [.fullScreenPrimary]
        comparisonWindow.contentMinSize = NSSize(width: 800, height: 500)
        comparisonWindow.contentView = NSHostingView(rootView: FileDiffView(model: model, file: file))
        comparisonWindow.delegate = self
        window = comparisonWindow
        comparisonWindow.setFrame(frame, display: false)
        if showWindow {
            comparisonWindow.makeKeyAndOrderFront(nil)
            comparisonWindow.toggleFullScreen(nil)
        }
    }
    func dismiss() {
        guard let window, !dismissing else { return }
        dismissing = true
        window.close()
        self.window = nil
        dismissing = false
    }
    func windowWillClose(_ notification: Notification) {
        window = nil
        if !dismissing { model.closeDiff() }
        if showWindow { sourceWindow?.makeKeyAndOrderFront(nil) }
    }
}
