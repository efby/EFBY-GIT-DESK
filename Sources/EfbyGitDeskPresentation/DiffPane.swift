import SwiftUI
import AppKit

struct DiffPane: View {
    @Bindable var model: DeskModel
    @State private var collapsed: Set<String> = []
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text(title).font(.headline)
                    Spacer()
                }
                ForEach(Array(model.orderedComparison.reversed()), id: \.self) { oid in
                    if let commit = model.commits.first(where: { $0.oid == oid }) {
                        ComparisonCommitCard(commit: commit, revisionLabel: model.selectedOIDs.count == 2
                            ? (oid == model.orderedComparison.first ? "A · Inferior · Origen" : "B · Superior · Destino") : "Commit")
                    }
                }
                if model.selectedOIDs.count == 1,
                   let commit = model.commits.first(where: { $0.oid == model.selectedOIDs[0] }), commit.parents.count > 1 {
                    Picker("Padre del merge", selection: $model.parentIndex) {
                        ForEach(commit.parents.indices, id: \.self) { Text("Padre \($0 + 1)").tag($0) }
                    }.onChange(of: model.parentIndex) { _, _ in model.loadFiles() }
                }
                if model.context != nil { Text(model.filesLoading ? "Consultando inventario…" : "\(model.files.count) archivos cambiados · inventario completo").font(.caption).foregroundStyle(.secondary) }
                Button("Editar mensaje de HEAD", systemImage: "pencil.line") { model.beginAmend() }
                    .disabled(!model.mutable || model.snapshot.head.isEmpty)
            }.padding(14)
            Divider()
            if model.context == nil {
                ContentUnavailableView("Selecciona un commit", systemImage: "arrow.left.arrow.right",
                    description: Text("Selecciona dos para comparar sus árboles A→B. Los cambios locales se revisan por separado."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    Text("Haz clic en un archivo para ver sus diferencias.")
                        .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 12).padding(.vertical, 6)
                    if model.files.isEmpty && !model.filesLoading {
                        ContentUnavailableView("Sin archivos cambiados", systemImage: "doc", description: Text("No hay diferencias en esta selección."))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else { fileList }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
    }
    private var fileList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 1) {
                Button("Expandir todo") { collapsed.removeAll() }
                    .buttonStyle(.plain).padding(.bottom, 3)
                ComparisonTreeRows(model: model, nodes: ComparisonFileNode.make(model.files), collapsed: $collapsed)
            }.padding(.horizontal, 12).padding(.vertical, 6).frame(maxWidth: .infinity, alignment: .leading)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var title: String {
        if model.workingView { return model.stagedView ? "HEAD → Índice" : "Índice → Working tree" }
        return model.selectedOIDs.count == 2 ? "Comparación A → B" : "Detalle del commit"
    }
}
