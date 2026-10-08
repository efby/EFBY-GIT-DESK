import SwiftUI

struct ParallelDiffView: NSViewRepresentable {
    let rows: [DiffRow]
    let blocks: [DiffChangeBlock]
    let inline: [DiffInlineRow]
    let marks: [DiffMapMark]
    var syntax: DiffSyntax? = nil
    var links: CodeCallLinks? = nil
    var jump: DiffJumpTarget? = nil
    var onFollow: ((String, Int, Bool, String) -> Void)? = nil
    @Binding var viewport: DiffViewportStatus?
    func makeNSView(context: Context) -> ParallelDiffContainer { ParallelDiffContainer() }
    func updateNSView(_ view: ParallelDiffContainer, context: Context) {
        view.onViewportChange = { status in
            Task { @MainActor in if viewport != status { viewport = status } }
        }
        view.onFollow = onFollow
        view.update(rows, syntax: syntax, blocks: blocks, marks: marks, inline: inline, links: links)
        view.jump(to: jump)
    }
}
