import SwiftUI

struct ComparisonTreeLine: Identifiable, Sendable {
    let id: String
    let depth: Int
    let name: String
    let fileID: String?
    let status: String
    let fileName: String
    let folderID: String?
    let count: Int
}

extension ComparisonFileNode {
    static func lines(_ nodes: [ComparisonFileNode], collapsed: Set<String>, depth: Int = 0) -> [ComparisonTreeLine] {
        nodes.flatMap { node -> [ComparisonTreeLine] in
            if let file = node.file {
                return [ComparisonTreeLine(id: node.id, depth: depth, name: node.name, fileID: file.id, status: file.status, fileName: file.name, folderID: nil, count: 1)]
            }
            let header = ComparisonTreeLine(id: node.id, depth: depth, name: node.name, fileID: nil, status: "", fileName: "", folderID: node.id, count: node.count)
            guard !collapsed.contains(node.id) else { return [header] }
            return [header] + lines(node.children, collapsed: collapsed, depth: depth + 1)
        }
    }
}

struct ComparisonTreeRows: View {
    let lines: [ComparisonTreeLine]
    let selectedFile: String?
    let collapsed: Set<String>
    let toggleFolder: (String) -> Void
    let openFile: (String) -> Void
    var body: some View {
        ForEach(lines) { line in
            if let fileID = line.fileID {
                Button { openFile(fileID) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: symbol(line.status)).foregroundStyle(tint(line.status))
                        Text(line.name).lineLimit(1).truncationMode(.middle)
                        Spacer(minLength: 0)
                    }.padding(.vertical, 3).padding(.leading, 8 + CGFloat(line.depth) * 18).padding(.trailing, 8)
                        .contentShape(Rectangle())
                        .background(selectedFile == fileID ? Color.accentColor.opacity(0.22) : .clear)
                }.buttonStyle(.plain).help(line.fileName)
                    .accessibilityIdentifier("comparisonFile-" + fileID)
                    .accessibilityLabel("\(line.status == "=" ? "Sin cambios" : line.status): Ver \(line.status == "=" ? "contenido" : "diferencias") de \(line.fileName)")
            } else if let folderID = line.folderID {
                Button { toggleFolder(folderID) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: collapsed.contains(folderID) ? "chevron.right" : "chevron.down")
                            .font(.caption).frame(width: 12)
                        Text(line.name).lineLimit(1)
                        Text("\(line.count)").font(.caption).foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                    }.padding(.vertical, 3).padding(.leading, CGFloat(line.depth) * 18).foregroundStyle(.secondary).contentShape(Rectangle())
                }.buttonStyle(.plain)
                    .accessibilityLabel("\(collapsed.contains(folderID) ? "Expandir" : "Contraer") carpeta \(line.name), \(line.count) archivos")
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
