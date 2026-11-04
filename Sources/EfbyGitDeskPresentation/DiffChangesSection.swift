import SwiftUI

struct DiffChangesSection: View {
    let blocks: [DiffChangeBlock]
    let lineEndingCount: Int
    let viewport: DiffViewportStatus?
    @Binding var jump: DiffJumpTarget?
    var body: some View {
        HStack(spacing: 12) {
            Label("Modificaciones", systemImage: "map").font(.caption.bold())
            Label("Eliminado", systemImage: "minus").foregroundStyle(.red)
            Label("Agregado", systemImage: "plus").foregroundStyle(.green)
            Text(statusMessage)
                .foregroundStyle(.secondary).lineLimit(1).truncationMode(.tail)
                .help(statusMessage)
            Spacer(minLength: 0)
            Button("Cambio anterior", systemImage: "chevron.up") {
                if let previous { jump = DiffJumpTarget(row: previous.firstRow) }
            }.labelStyle(.iconOnly).disabled(previous == nil)
            Button("Cambio siguiente", systemImage: "chevron.down") {
                if let next { jump = DiffJumpTarget(row: next.firstRow) }
            }.labelStyle(.iconOnly).disabled(next == nil)
        }.font(.caption).padding(.horizontal, 12).padding(.vertical, 8)
    }
    private var statusMessage: String {
        blocks.isEmpty
            ? (lineEndingCount > 0 ? "Solo cambian finales de línea." : "No hay cambios de líneas.")
            : viewport?.message ?? "Calculando posición…"
    }
    private var currentRow: Int {
        guard let viewport else { return jump?.row ?? 0 }
        if let jump, (viewport.firstRow...viewport.lastRow).contains(jump.row) { return jump.row }
        return viewport.firstRow
    }
    private var previous: DiffChangeBlock? { blocks.last { $0.firstRow < currentRow } }
    private var next: DiffChangeBlock? { blocks.first { $0.firstRow > currentRow } }
}
