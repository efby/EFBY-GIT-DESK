import SwiftUI
import EfbyGitDeskDomain

/// A separate comparison window leaves the repository's native views mounted.
struct ComparisonWindowPresenter: NSViewRepresentable {
    let model: DeskModel
    let file: FileChange?
    func makeCoordinator() -> ComparisonWindowCoordinator { ComparisonWindowCoordinator(model: model) }
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ view: NSView, context: Context) {
        context.coordinator.update(file: file, source: view.window)
    }
    static func dismantleNSView(_ view: NSView, coordinator: ComparisonWindowCoordinator) { coordinator.dismiss() }
}
