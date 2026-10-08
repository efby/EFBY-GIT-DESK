import SwiftUI

struct ComparisonTreeRows: View {
    @Bindable var model: DeskModel
    let nodes: [ComparisonFileNode]
    let collapsed: Set<String>
    let toggleFolder: (String) -> Void
    var body: some View {
        ForEach(nodes) { node in
            if let file = node.file {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        if model.showAllFiles && CodeSymbolIndex.supports(CodeLanguage.detect(path: file.name)) {
                            Button { model.toggleSymbols(for: file.id) } label: {
                                Image(systemName: model.expandedSymbolFiles.contains(file.id) ? "chevron.down" : "chevron.right")
                                    .font(.caption).frame(width: 18)
                            }.buttonStyle(.plain)
                                .accessibilityLabel("\(model.expandedSymbolFiles.contains(file.id) ? "Ocultar" : "Mostrar") funciones de \(file.name)")
                        }
                        Button { model.loadDiff(id: file.id) } label: {
                            HStack(spacing: 8) {
                                Image(systemName: symbol(file.status)).foregroundStyle(tint(file.status))
                                Text(node.name).lineLimit(1).truncationMode(.middle)
                                Spacer(minLength: 0)
                            }.padding(.vertical, 3).padding(.horizontal, 8)
                                .contentShape(Rectangle())
                                .background(model.selectedFile == file.id ? Color.accentColor.opacity(0.22) : .clear)
                        }.buttonStyle(.plain).help(file.name)
                            .accessibilityIdentifier("comparisonFile-" + file.id)
                            .accessibilityLabel("\(file.status == "=" ? "Sin cambios" : file.status): Ver \(file.status == "=" ? "contenido" : "diferencias") de \(file.name)")
                    }
                    if model.showAllFiles && model.expandedSymbolFiles.contains(file.id) {
                        VStack(alignment: .leading, spacing: 2) {
                            if model.symbolsLoading.contains(file.id) {
                                ProgressView("Buscando funciones…").controlSize(.small)
                            } else if let message = model.symbolErrors[file.id] {
                                Text(message).font(.caption2).foregroundStyle(.orange)
                            } else if let symbols = model.codeSymbols[file.id] {
                                if symbols.isEmpty { Text("Sin funciones detectadas").font(.caption2).foregroundStyle(.secondary) }
                                ForEach(symbols) { item in
                                    Button { model.navigateToSymbol(fileID: file.id, symbol: item) } label: {
                                        Text("ƒ \(item.name) · \(item.line)")
                                            .font(.caption.monospaced()).lineLimit(1).truncationMode(.middle)
                                            .foregroundStyle(.tint).underline()
                                    }.buttonStyle(.plain)
                                        .accessibilityLabel("Ir a \(item.name), línea \(item.line), en \(file.name)")
                                }
                            }
                        }.padding(.leading, 26)
                            .task(id: model.fileInventoryRevision) { model.loadSymbols(for: file.id) }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    Button { toggleFolder(node.id) } label: {
                        HStack(spacing: 8) {
                            Image(systemName: collapsed.contains(node.id) ? "chevron.right" : "chevron.down")
                                .font(.caption).frame(width: 12)
                            Text(node.name).lineLimit(1)
                            Text("\(node.count)").font(.caption).foregroundStyle(.secondary)
                            Spacer(minLength: 0)
                        }.padding(.vertical, 3).foregroundStyle(.secondary).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                        .accessibilityLabel("\(collapsed.contains(node.id) ? "Expandir" : "Contraer") carpeta \(node.name), \(node.count) archivos")
                    if !collapsed.contains(node.id) {
                        ComparisonTreeRows(model: model, nodes: node.children, collapsed: collapsed, toggleFolder: toggleFolder).padding(.leading, 18)
                    }
                }
            }
        }
    }
    private func symbol(_ status: String) -> String {
        switch status.first { case "A": "plus"; case "D": "minus"; case "R": "arrow.turn.up.right"; case "=": "doc.text"; default: "pencil" }
    }
    private func tint(_ status: String) -> Color {
        switch status.first { case "A": .green; case "D": .red; case "=": .secondary; default: .orange }
    }
}
