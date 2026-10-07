import SwiftUI

struct ParallelDiffView: NSViewRepresentable {
    let rows: [DiffRow]
    let blocks: [DiffChangeBlock]
    let marks: [DiffMapMark]
    var syntax: DiffSyntax? = nil
    var jump: DiffJumpTarget? = nil
    @Binding var viewport: DiffViewportStatus?
    func makeNSView(context: Context) -> ParallelDiffContainer { ParallelDiffContainer() }
    func updateNSView(_ view: ParallelDiffContainer, context: Context) {
        view.onViewportChange = { status in
            Task { @MainActor in if viewport != status { viewport = status } }
        }
        view.update(rows, syntax: syntax, blocks: blocks, marks: marks)
        view.jump(to: jump)
    }
}
