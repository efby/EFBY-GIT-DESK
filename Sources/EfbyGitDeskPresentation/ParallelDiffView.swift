import SwiftUI

struct ParallelDiffView: NSViewRepresentable {
    let rows: [DiffRow]
    let blocks: [DiffChangeBlock]
    let inline: [DiffInlineRow]
    let marks: [DiffMapMark]
    var syntax: DiffSyntax? = nil
    var links: CodeCallLinks? = nil
    var documentRevision = 0
    var jump: DiffJumpTarget? = nil
    var onFollow: ((String, Int, Bool, String, Int, CGFloat, CGFloat) -> Void)? = nil
    @Binding var viewport: DiffViewportStatus?
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> ParallelDiffContainer { ParallelDiffContainer() }
    func updateNSView(_ view: ParallelDiffContainer, context: Context) {
        let coordinator = context.coordinator
        view.onViewportChange = { status in
            coordinator.latest = status
            guard !coordinator.scheduled else { return }
            coordinator.scheduled = true
            DispatchQueue.main.async {
                coordinator.scheduled = false
                if let status = coordinator.latest, viewport != status { viewport = status }
            }
        }
        view.onFollow = onFollow
        let jumpID = jump?.id
        if coordinator.documentRevision == documentRevision, coordinator.jumpID == jumpID { return }
        coordinator.documentRevision = documentRevision
        coordinator.jumpID = jumpID
        view.update(rows, syntax: syntax, blocks: blocks, marks: marks, inline: inline, links: links)
        view.jump(to: jump)
    }
    final class Coordinator {
        var latest: DiffViewportStatus?
        var scheduled = false
        var documentRevision: Int?
        var jumpID: UUID?
    }
}
