import SwiftUI
import AppKit

struct DiffPane: View {
    @Bindable var model: DeskModel
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text(title).font(.headline)
                    Spacer()
                    if model.selectedOIDs.count == 2 {
                        Button("Intercambiar A y B", systemImage: "arrow.left.arrow.right") { model.swapComparison() }.labelStyle(.iconOnly).help("Intercambiar A y B")
                    }
                }
                ForEach(Array(model.selectedOIDs.enumerated()), id: \.element) { index, oid in
                    HStack {
                        Text(model.selectedOIDs.count == 2 ? (index == 0 ? "A · Base" : "B · Destino") : "Commit").foregroundStyle(.teal)
                        Text(String(oid.prefix(12))).font(.caption.monospaced())
                        Spacer()
                        Button("Copiar SHA completo", systemImage: "doc.on.doc") {
                            NSPasteboard.general.clearContents(); NSPasteboard.general.setString(oid, forType: .string)
                        }.labelStyle(.iconOnly)
                    }.font(.caption)
                }
                if model.selectedOIDs.count == 1,
                   let commit = model.commits.first(where: { $0.oid == model.selectedOIDs[0] }), commit.parents.count > 1 {
                    Picker("Padre del merge", selection: $model.parentIndex) {
                        ForEach(commit.parents.indices, id: \.self) { Text("Padre \($0 + 1)").tag($0) }
                    }.onChange(of: model.parentIndex) { _, _ in model.loadFiles() }
                }
                if model.context != nil { Text(model.filesLoading ? "Consultando inventario…" : "\(model.files.count) rutas cambiadas · inventario completo").font(.caption).foregroundStyle(.secondary) }
                Button("Editar mensaje de HEAD", systemImage: "pencil.line") { model.beginAmend() }
                    .disabled(!model.mutable || model.snapshot.head.isEmpty)
            }.padding(14)
            Divider()
            if model.context == nil {
                ContentUnavailableView("Selecciona un commit", systemImage: "arrow.left.arrow.right",
                    description: Text("Selecciona dos para comparar sus árboles A→B. Los cambios locales se revisan por separado."))
            } else {
                List(model.files, selection: $model.selectedFile) { file in
                    HStack {
                        Text(file.status).font(.caption.monospaced()).frame(width: 28)
                        Text(file.name).font(.caption).lineLimit(1).truncationMode(.middle)
                    }.tag(file.id)
                }.frame(minHeight: 90, idealHeight: 160, maxHeight: 220)
                    .onChange(of: model.selectedFile) { _, id in if let id { model.loadDiff(id: id) } }
                Divider()
                TextPreview(text: model.diffText)
            }
        }.background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
    }
    private var title: String {
        if model.workingView { return model.stagedView ? "HEAD → Índice" : "Índice → Working tree" }
        return model.selectedOIDs.count == 2 ? "Comparación A → B" : "Detalle del commit"
    }
}
