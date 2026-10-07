import SwiftUI
import EfbyGitDeskDomain

struct FileDiffView: View {
    @Bindable var model: DeskModel
    let file: FileChange
    @State private var jump: DiffJumpTarget?
    @State private var viewport: DiffViewportStatus?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button("Cerrar", systemImage: "xmark", action: model.closeDiff)
                    .buttonStyle(CloseComparisonButtonStyle()).controlSize(.large)
                    .fixedSize().layoutPriority(1)
                    .keyboardShortcut(.escape, modifiers: [])
                    .accessibilityIdentifier("closeComparison")
                    .help("Cerrar solo el visor y volver al repositorio (Esc)")
                Label(file.name, systemImage: "doc.text")
                    .font(.caption.monospaced()).lineLimit(1).truncationMode(.middle)
                    .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                Picker("Formato de código", selection: $model.syntaxLanguage) {
                    ForEach(CodeLanguage.allCases) { language in Text(language.rawValue).tag(language) }
                }.labelsHidden().frame(width: 180).help("Detectar el lenguaje por extensión o elegirlo manualmente")
                Text(model.detectedLanguageLabel).font(.caption).foregroundStyle(.secondary)
                Text("Esc para volver").font(.caption).foregroundStyle(.secondary).fixedSize()
            }.padding(12)
            Divider()
            if model.diffLoading {
                ProgressView("Comparando documentos…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let comparison = model.comparison {
                if !model.diffNotice.isEmpty {
                    Text(model.diffNotice).font(.caption).foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(8)
                }
                if !missingFinalNewline(comparison).isEmpty {
                    Text(missingFinalNewline(comparison)).font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8).padding(.vertical, 4)
                }
                if model.diffAligned && comparison.before != nil && comparison.after != nil && !comparison.patch.contains("[Diff truncado") {
                    DiffChangesSection(blocks: model.diffBlocks, viewport: viewport, jump: $jump)
                    Divider()
                    ParallelDiffView(rows: model.diffRows, blocks: model.diffBlocks, inline: model.diffInline, marks: model.diffMap, syntax: model.diffSyntax, jump: jump, viewport: $viewport).frame(maxWidth: .infinity, maxHeight: .infinity)
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

    private func missingFinalNewline(_ comparison: FileComparison) -> String {
        var sides: [String] = []
        if let text = comparison.before, !text.isEmpty, text.utf8.last != 10 { sides.append("izquierda") }
        if let text = comparison.after, !text.isEmpty, text.utf8.last != 10 { sides.append("derecha") }
        return sides.isEmpty ? "" : "Sin salto de línea final: " + sides.joined(separator: " y ")
    }
}
