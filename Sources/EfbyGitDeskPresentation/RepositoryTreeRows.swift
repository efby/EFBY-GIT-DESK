import SwiftUI
import EfbyGitDeskDomain

struct RepositoryTreeRows<RowContent: View>: View {
    let nodes: [RepositoryTreeNode]
    let collapsed: Set<String>
    let onToggle: (String, Bool) -> Void
    var onDiscardFolder: ((String) -> Void)?
    var onRescanFolder: ((String) -> Void)?
    let row: (Repository) -> RowContent

    var body: some View {
        ForEach(nodes) { node in
            if let children = node.children, !children.isEmpty {
                DisclosureGroup(isExpanded: Binding(
                    get: { !collapsed.contains(node.id) },
                    set: { onToggle(node.id, $0) }
                )) {
                    RepositoryTreeRows(nodes: children, collapsed: collapsed, onToggle: onToggle,
                                       onDiscardFolder: onDiscardFolder, onRescanFolder: onRescanFolder, row: row)
                } label: {
                    if let repository = node.repository { row(repository) }
                    else {
                        Label(node.name, systemImage: "folder").font(.body.weight(.medium))
                            .help(node.id).accessibilityLabel("Carpeta " + node.name)
                            .contextMenu { folderMenu(for: node.id) }
                    }
                }
            } else if let repository = node.repository {
                row(repository)
            }
        }
    }

    @ViewBuilder
    private func folderMenu(for path: String) -> some View {
        if let onRescanFolder {
            Button("Volver a escanear carpeta", systemImage: "arrow.clockwise") { onRescanFolder(path) }
        }
        if let onDiscardFolder {
            Button("Quitar carpeta del registro", systemImage: "folder.badge.minus", role: .destructive) { onDiscardFolder(path) }
        }
    }
}
