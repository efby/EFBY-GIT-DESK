import SwiftUI

struct ComparisonTreeRows: View {
    @Bindable var model: DeskModel
    let nodes: [ComparisonFileNode]
    let collapsed: Set<String>
    let toggleFolder: (String) -> Void
    var body: some View {
        ForEach(nodes) { node in
            if let file = node.file {
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
