import SwiftUI
import EfbyGitDeskDomain

struct RepositoryTreeRows<RowContent: View>: View {
    let nodes: [RepositoryTreeNode]
    let collapsed: Set<String>
    let onToggle: (String, Bool) -> Void
    let onSelect: (String) -> Void
    let row: (Repository) -> RowContent

    var body: some View {
        ForEach(nodes) { node in
            if let children = node.children, !children.isEmpty {
                DisclosureGroup(isExpanded: Binding(
                    get: { !collapsed.contains(node.id) },
                    set: { onToggle(node.id, $0) }
                )) {
                    RepositoryTreeRows(nodes: children, collapsed: collapsed, onToggle: onToggle, onSelect: onSelect, row: row)
                } label: {
                    if let repository = node.repository { repositoryButton(repository) }
                    else {
                        Label(node.name, systemImage: "folder").font(.body.weight(.medium))
                            .help(node.id).accessibilityLabel("Carpeta " + node.name)
                    }
                }
            } else if let repository = node.repository {
                repositoryButton(repository)
            }
        }
    }

    private func repositoryButton(_ repository: Repository) -> some View {
        Button { onSelect(repository.id) } label: { row(repository) }.buttonStyle(.plain)
    }
}
