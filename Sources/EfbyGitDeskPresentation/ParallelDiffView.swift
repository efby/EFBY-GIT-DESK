import SwiftUI

struct ParallelDiffView: NSViewRepresentable {
    let rows: [DiffRow]
    func makeNSView(context: Context) -> ParallelDiffContainer { ParallelDiffContainer() }
    func updateNSView(_ view: ParallelDiffContainer, context: Context) { view.update(rows) }
}
