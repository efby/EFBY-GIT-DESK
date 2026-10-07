import SwiftUI

struct ParallelDiffView: NSViewRepresentable {
    let rows: [DiffRow]
    var syntax: DiffSyntax? = nil
    func makeNSView(context: Context) -> ParallelDiffContainer { ParallelDiffContainer() }
    func updateNSView(_ view: ParallelDiffContainer, context: Context) { view.update(rows, syntax: syntax) }
}
