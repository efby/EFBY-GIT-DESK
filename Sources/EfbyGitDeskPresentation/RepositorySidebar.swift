import SwiftUI
import AppKit
import EfbyGitDeskDomain

struct RepositorySidebar: View {
    @Bindable var model: DeskModel
    @State private var editing: Repository?
    @State private var group = ""
    private var filtered: [Repository] {
        model.repositories.filter {
            model.repositorySearch.isEmpty || ($0.name + " " + $0.path + " " + $0.group)
                .localizedCaseInsensitiveContains(model.repositorySearch)
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("EF").font(.title3.bold()).padding(9).background(.teal.opacity(0.2), in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading) {
                    Text("EfbyGitDesk").font(.headline)
                    Text("BITBUCKET CLOUD").font(.caption2).foregroundStyle(.secondary)
                }
            }.padding(.horizontal, 16).padding(.top, 14)
            TextField("Buscar repositorios", text: $model.repositorySearch).textFieldStyle(.roundedBorder).padding(.horizontal, 12)
            List(selection: $model.selectedID) {
                Section("Favoritos") { ForEach(filtered.filter(\.favorite)) { repositoryRow($0) } }
                Section("Recientes") { ForEach(filtered.filter { $0.group.isEmpty && !$0.favorite }) { repositoryRow($0) } }
                ForEach(Array(Set(filtered.map(\.group).filter { !$0.isEmpty })).sorted(), id: \.self) { name in
                    Section(name) { ForEach(filtered.filter { $0.group == name }) { repositoryRow($0) } }
                }
            }.listStyle(.sidebar)
            if filtered.isEmpty && !model.repositories.isEmpty { Text("Sin coincidencias").foregroundStyle(.secondary).padding() }
            Text("\(model.repositories.count) repositorios locales").font(.caption).foregroundStyle(.secondary).padding(16)
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
