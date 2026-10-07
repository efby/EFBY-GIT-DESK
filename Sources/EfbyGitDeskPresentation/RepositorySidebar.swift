import SwiftUI
import AppKit
import EfbyGitDeskDomain

struct RepositorySidebar: View {
    @Bindable var model: DeskModel
    @State private var editing: Repository?
    @State private var group = ""
    @State private var tree: [RepositoryTreeNode] = []
    private var filtered: [Repository] {
        model.repositories.filter {
            model.repositorySearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || ($0.name + " " + $0.path + " " + $0.group)
                .localizedStandardContains(model.repositorySearch.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("EF").font(.title3.bold()).padding(9).background(.teal.opacity(0.2), in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading) {
                    Text("EFBY Git Desk").font(.headline)
                    Text("BITBUCKET CLOUD").font(.caption2).foregroundStyle(.secondary)
                }
            }.padding(.horizontal, 16).padding(.top, 14)
            TextField("Buscar en todos los proyectos", text: $model.repositorySearch).textFieldStyle(.roundedBorder).padding(.horizontal, 12)
            List(selection: $model.sidebarSelection) {
                if !model.repositorySearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section("Resultados en todos los proyectos") {
                        ForEach(filtered) { repositoryRow($0) }
                    }
                } else {
                    if model.repositories.contains(where: \.favorite) {
                        Section("Favoritos") { ForEach(model.repositories.filter(\.favorite)) { repositoryRow($0).id("favorite:" + $0.id) } }
                    }
                    Section("Proyectos") {
                        OutlineGroup(tree, children: \.children) { node in
                            if let repository = node.repository { repositoryRow(repository) }
                            else {
                                Label(node.name, systemImage: "folder").font(.body.weight(.medium))
                                    .help(node.id).accessibilityLabel("Carpeta " + node.name)
                            }
                        }
                    }
                    ForEach(Array(Set(model.repositories.map(\.group).filter { !$0.isEmpty })).sorted(), id: \.self) { name in
                        Section(name) { ForEach(model.repositories.filter { $0.group == name }) { repositoryRow($0).id("group:" + $0.id) } }
                    }
                }
            }.listStyle(.sidebar)
            if filtered.isEmpty && !model.repositories.isEmpty { Text("Sin coincidencias").foregroundStyle(.secondary).padding() }
            Button("Agregar carpeta", systemImage: "folder.badge.plus") { model.chooseRepository() }
                .buttonStyle(.bordered).disabled(model.busy).padding(.horizontal, 12)
            Text("\(model.repositories.count) repositorios locales").font(.caption).foregroundStyle(.secondary).padding(16)
        }
        .task(id: RepositoryTreeSnapshot(repositories: model.repositories, roots: model.folderRoots)) {
            let repositories = model.repositories, roots = model.folderRoots
            let result = await Task.detached { RepositoryTreeBuilder.make(repositories: repositories, roots: roots) }.value
            if !Task.isCancelled { tree = result }
        }
        .sheet(item: $editing) { repository in
            VStack(alignment: .leading, spacing: 18) {
                Text("Grupo local").font(.title2.bold())
                Text(repository.name).foregroundStyle(.secondary)
                TextField("Nombre del grupo (vacío para quitar)", text: $group).textFieldStyle(.roundedBorder)
                HStack {
                    Button("Cancelar") { editing = nil }
                    Spacer()
                    Button("Guardar") {
                        var value = repository; value.group = group
                        model.update(value); editing = nil
                    }.buttonStyle(.borderedProminent)
                }
            }.padding(24).frame(width: 400)
        }
    }
    private func repositoryRow(_ repository: Repository) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(repository.name, systemImage: repository.trusted ? "folder" : "lock.shield")
                .font(.body.weight(repository.id == model.selectedID ? .semibold : .regular))
            Text(repository.path).font(.caption2).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
        }.padding(.vertical, 4).tag(repository.id)
        .contextMenu {
            Button(repository.favorite ? "Quitar favorito" : "Marcar favorito", systemImage: "star") {
                var value = repository; value.favorite.toggle(); model.update(value)
            }
            Button("Asignar grupo", systemImage: "folder.badge.gearshape") { group = repository.group; editing = repository }
            Button("Mostrar en Finder", systemImage: "folder") { NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: repository.path) }
            Button("Quitar del registro", systemImage: "minus.circle", role: .destructive) { model.remove(repository) }
        }
    }
}
