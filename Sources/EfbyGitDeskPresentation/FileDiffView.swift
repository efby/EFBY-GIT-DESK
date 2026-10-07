import SwiftUI
import EfbyGitDeskDomain

struct FileDiffView: View {
    @Bindable var model: DeskModel
    let file: FileChange

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(file.name, systemImage: "doc.text")
                    .font(.caption.monospaced()).lineLimit(2).textSelection(.enabled)
                Spacer()
                Picker("Formato de código", selection: $model.syntaxLanguage) {
                    ForEach(CodeLanguage.allCases) { language in Text(language.rawValue).tag(language) }
                }.labelsHidden().frame(width: 180).help("Detectar el lenguaje por extensión o elegirlo manualmente")
                Text(model.detectedLanguageLabel).font(.caption).foregroundStyle(.secondary)
                Button("Volver al repositorio", systemImage: "arrow.backward", action: model.closeDiff)
                    .keyboardShortcut(.escape, modifiers: []).help("Cerrar la comparación y volver a la vista anterior")
            }.padding(12)
            Divider()
            if model.diffLoading {
                ProgressView("Comparando documentos…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let comparison = model.comparison {
                HStack(spacing: 0) {
                    DiffDocumentHeader(title: "Documento 1 · Inferior / Base", revision: comparison.beforeLabel,
                                       path: file.oldPath.flatMap { String(data: $0, encoding: .utf8) } ?? file.name,
                                       text: comparison.before)
                    Divider()
                    DiffDocumentHeader(title: "Documento 2 · Superior / Destino", revision: comparison.afterLabel,
                                       path: file.name, text: comparison.after)
                }.fixedSize(horizontal: false, vertical: true)
                Divider()
                if !model.diffNotice.isEmpty {
                    Text(model.diffNotice).font(.caption).foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(8)
                }
                if model.diffAligned && comparison.before != nil && comparison.after != nil && !comparison.patch.contains("[Diff truncado") {
                    ParallelDiffView(rows: model.diffRows, syntax: model.diffSyntax).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    TextPreview(text: model.diffText).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                ContentUnavailableView("No se pudo comparar", systemImage: "doc.text.magnifyingglass",
                    description: Text("Actualiza el repositorio y vuelve a seleccionar el archivo."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
            .preferredColorScheme(.dark)
            .onChange(of: model.syntaxLanguage) { _, _ in model.refreshHighlighting() }
    }
}
