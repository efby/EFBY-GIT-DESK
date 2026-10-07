import SwiftUI

struct DiffChangesSection: View {
    let blocks: [DiffChangeBlock]
    let viewport: DiffViewportStatus?
    @Binding var jump: DiffJumpTarget?
    var body: some View {
        HStack(spacing: 12) {
            Label("Modificaciones", systemImage: "map").font(.caption.bold())
            Label("Eliminado", systemImage: "minus").foregroundStyle(.red)
            Label("Agregado", systemImage: "plus").foregroundStyle(.green)
            Text(blocks.isEmpty ? "No hay cambios de líneas." : viewport?.message ?? "Calculando posición…")
                .foregroundStyle(.secondary).lineLimit(2)
            Spacer(minLength: 0)
            Button("Cambio anterior", systemImage: "chevron.up") {
                if let previous { jump = DiffJumpTarget(row: previous.firstRow) }
            }.labelStyle(.iconOnly).disabled(previous == nil)
            Button("Cambio siguiente", systemImage: "chevron.down") {
                if let next { jump = DiffJumpTarget(row: next.firstRow) }
            }.labelStyle(.iconOnly).disabled(next == nil)
        }.font(.caption).padding(.horizontal, 12).padding(.vertical, 8)
    }
    private var currentRow: Int {
        guard let viewport else { return jump?.row ?? 0 }
        if let jump, (viewport.firstRow...viewport.lastRow).contains(jump.row) { return jump.row }
        return viewport.firstRow
    }
    private var previous: DiffChangeBlock? { blocks.last { $0.firstRow < currentRow } }
    private var next: DiffChangeBlock? { blocks.first { $0.firstRow > currentRow } }
}
