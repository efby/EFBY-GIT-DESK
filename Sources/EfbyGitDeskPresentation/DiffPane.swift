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
                }
                ForEach(Array(model.orderedComparison.enumerated()), id: \.element) { index, oid in
                    HStack {
                        Text(model.selectedOIDs.count == 2 ? (index == 0 ? "A · Inferior" : "B · Superior") : "Commit").foregroundStyle(.teal)
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    Text("Haz clic en un archivo para ver sus diferencias.")
                        .font(.caption).foregroundStyle(.secondary).padding(12)
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
        List(model.files) { file in
            Button { model.loadDiff(id: file.id) } label: {
                HStack {
                    Text(file.status).font(.caption.monospaced()).frame(width: 28)
                    Text(file.name).font(.caption).lineLimit(1).truncationMode(.middle)
                    Spacer(minLength: 0)
                }.padding(.vertical, 4).contentShape(Rectangle())
                    .background(model.selectedFile == file.id ? Color.teal.opacity(0.18) : .clear)
            }.buttonStyle(.plain)
                .accessibilityLabel("Ver diferencias de \(file.name)")
                .help(file.name)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var title: String {
        if model.workingView { return model.stagedView ? "HEAD → Índice" : "Índice → Working tree" }
        return model.selectedOIDs.count == 2 ? "Comparación A → B" : "Detalle del commit"
    }
}
