import SwiftUI

struct RepositoryTabs: View {
    @Bindable var model: DeskModel
    var body: some View {
        if !model.openIDs.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(model.openIDs, id: \.self) { id in
                        if let repository = model.repositories.first(where: { $0.id == id }) {
                            HStack(spacing: 6) {
                                Button(repository.name) { model.select(id) }.buttonStyle(.plain)
                                Button("Cerrar \(repository.name)", systemImage: "xmark") { model.closeRepository(id) }
                                    .labelStyle(.iconOnly).buttonStyle(.plain).disabled(model.busy)
                            }.font(.caption).padding(9)
                                .background(id == model.selectedID ? Color.teal.opacity(0.2) : .clear, in: RoundedRectangle(cornerRadius: 6))
                                .help(repository.path)
                                .contextMenu {
                                    Button("Cerrar pestaña", systemImage: "xmark") { model.closeRepository(id) }
                                        .disabled(model.busy)
                                    Button("Cerrar otras pestañas", systemImage: "rectangle.on.rectangle.slash") {
                                        model.closeRepositoryTabs(relativeTo: id, scope: .others)
                                    }.disabled(model.busy || model.openIDs.count < 2)
                                    Button("Cerrar pestañas a la derecha", systemImage: "arrow.right.to.line") {
                                        model.closeRepositoryTabs(relativeTo: id, scope: .right)
                                    }.disabled(model.busy || RepositoryTabClosePlan.targets(in: model.openIDs, relativeTo: id, scope: .right).isEmpty)
                                    Button("Cerrar pestañas a la izquierda", systemImage: "arrow.left.to.line") {
                                        model.closeRepositoryTabs(relativeTo: id, scope: .left)
                                    }.disabled(model.busy || RepositoryTabClosePlan.targets(in: model.openIDs, relativeTo: id, scope: .left).isEmpty)
                                    Divider()
                                    Button("Abrir en Terminal", systemImage: "terminal") { model.openExternalTerminal(for: id) }
                                        .disabled(model.busy || !repository.trusted || repository.inspectionReason != nil || repository.linkedWorktree)
                                    Button("Mostrar en Finder", systemImage: "folder") { model.showInFinder(id) }
                                    ExternalEditorMenuItems(path: repository.path) { editor in
                                        model.openInExternalEditor(id, editor: editor)
                                    }
                                }
                        }
                    }
                }.padding(.horizontal, 12).padding(.top, 6)
            }
        }
    }
}
