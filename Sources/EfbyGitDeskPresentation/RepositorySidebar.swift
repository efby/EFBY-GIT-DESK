import SwiftUI
import AppKit
import EfbyGitDeskDomain

private struct BulkTrustSelection: Identifiable {
    let id = UUID()
    let repositories: [Repository]
}

struct RepositorySidebar: View {
    @Bindable var model: DeskModel
    @State private var editing: Repository?
    @State private var group = ""
    @State private var tree: [RepositoryTreeNode] = []
    @State private var collapsedFolders: Set<String> = []
    @State private var folderStateLoaded = false
    @State private var expansionVersion = 0
    @State private var expansionSave: Task<Void, Never>?
    @State private var trustSelection: BulkTrustSelection?
    @State private var pendingTrustIDs: [String] = []
    private var untrusted: [Repository] { model.repositories.filter { !$0.trusted } }
    private var filtered: [Repository] {
        model.repositories.filter {
            model.repositorySearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || ($0.name + " " + $0.path + " " + $0.group)
                .localizedStandardContains(model.repositorySearch.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable().scaledToFit().frame(width: 52, height: 52)
                    .accessibilityLabel("Logo de EFBY Git Desk")
                Text("EFBY Git Desk").font(.headline)
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
                        if folderStateLoaded {
                            RepositoryTreeRows(nodes: tree, collapsed: collapsedFolders, onToggle: setFolder,
                                               onSelect: { model.sidebarSelection = $0 }) {
                                repositoryRow($0)
                            }
                        } else {
                            ProgressView("Restaurando carpetas…").controlSize(.small)
                        }
                    }
                    ForEach(Array(Set(model.repositories.map(\.group).filter { !$0.isEmpty })).sorted(), id: \.self) { name in
                        Section(name) { ForEach(model.repositories.filter { $0.group == name }) { repositoryRow($0).id("group:" + $0.id) } }
                    }
                }
            }.listStyle(.sidebar)
            if filtered.isEmpty && !model.repositories.isEmpty { Text("Sin coincidencias").foregroundStyle(.secondary).padding() }
            VStack(spacing: 6) {
                Button { model.chooseRepository() } label: {
                    Label("Agregar carpeta", systemImage: "folder.badge.plus")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .disabled(model.busy)
                Button { model.fetchAll() } label: {
                    Label("Fetch de todos", systemImage: "arrow.down.to.line")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .disabled(model.busy || model.repositories.isEmpty)
                .help("Obtiene cambios de todos los remotos de los repositorios confiables. Muestra cuáles se omitieron o fallaron.")
                Button {
                    trustSelection = BulkTrustSelection(repositories: untrusted.sorted {
                        $0.path.localizedStandardCompare($1.path) == .orderedAscending
                    })
                } label: {
                    Label("Confiar en todos (\(untrusted.count))", systemImage: "lock.shield")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .disabled(model.busy || untrusted.isEmpty)
                .help("Revisa los repositorios pendientes antes de conceder confianza a todos.")
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, 12)
            Text("\(model.repositories.count) repositorios locales").font(.caption).foregroundStyle(.secondary).padding(16)
        }
        .task(id: RepositoryTreeSnapshot(repositories: model.repositories, roots: model.folderRoots)) {
            let repositories = model.repositories, roots = model.folderRoots
            let result = await Task.detached { RepositoryTreeBuilder.make(repositories: repositories, roots: roots) }.value
            if !Task.isCancelled { tree = result }
        }
        .task {
            guard !folderStateLoaded else { return }
            let version = expansionVersion
            let key = FolderExpansionPreference.key(scope: "repositories", repositoryID: "workspace")
            let saved = try? await model.service.registry.preference(key)
            guard !Task.isCancelled, expansionVersion == version else { return }
            collapsedFolders = FolderExpansionPreference.decode(saved)
            folderStateLoaded = true
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
        .sheet(item: $trustSelection, onDismiss: {
            guard !pendingTrustIDs.isEmpty else { return }
            let ids = pendingTrustIDs
            pendingTrustIDs = []
            model.trustAll(ids: ids)
        }) { selection in
            BulkTrustSheet(repositories: selection.repositories) { ids in
                pendingTrustIDs = ids
                trustSelection = nil
            }
        }
    }
    private func setFolder(_ id: String, expanded: Bool) {
        var updated = collapsedFolders
        if expanded { updated.remove(id) } else { updated.insert(id) }
        guard updated != collapsedFolders else { return }
        collapsedFolders = updated; expansionVersion += 1
        guard let value = FolderExpansionPreference.encode(updated) else { return }
        let previous = expansionSave
        let service = model.service
        let key = FolderExpansionPreference.key(scope: "repositories", repositoryID: "workspace")
        expansionSave = Task {
            await previous?.value
            let registry = await service.registry
            try? await registry.setPreference(key, value: value)
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
