import SwiftUI
import AppKit
import EfbyGitDeskDomain

struct HistoryPane: View {
    @Bindable var model: DeskModel
    @State private var graph: [String: GraphRow] = [:]
    @State private var commitMessage = ""
    var body: some View {
        VStack(spacing: 0) {
            if model.workingView { working }
            else {
                HStack {
                    TextField("Buscar mensajes en todo el historial", text: $model.search).textFieldStyle(.roundedBorder)
                        .onChange(of: model.search) { _, _ in model.searchHistory() }
                    Text("\(model.commits.count) cargados").font(.caption).foregroundStyle(.secondary)
                }.padding(12)
                Divider()
                if model.loading && model.commits.isEmpty {
                    ProgressView("Cargando historial…").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if model.commits.isEmpty {
                    ContentUnavailableView("Sin commits", systemImage: "clock", description: Text("El repositorio está vacío o la búsqueda no tiene coincidencias."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(model.commits) { commit in
                                Button { model.chooseCommit(commit) } label: {
                                    HStack(spacing: 8) {
                                        GraphCell(row: graph[commit.oid])
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(commit.message).font(.body).lineLimit(1)
                                            HStack {
                                                Text(commit.author)
                                                Text(String(commit.date.prefix(10)))
                                                if !commit.references.isEmpty { Text(commit.references).foregroundStyle(.teal).lineLimit(1) }
                                            }.font(.caption2).foregroundStyle(.secondary)
                                        }
                                        Spacer(minLength: 4)
                                        Text(commit.shortOID).font(.caption.monospaced()).foregroundStyle(.secondary)
                                    }.padding(.trailing, 12)
                                    .background(model.selectedOIDs.contains(commit.oid) ? Color.teal.opacity(0.18) : .clear)
                                    .contentShape(Rectangle())
                                }.buttonStyle(.plain)
                                .accessibilityLabel("\(commit.message), \(commit.author), \(commit.shortOID)")
                                .contextMenu {
                                    Button("Copiar SHA completo", systemImage: "doc.on.doc") {
                                        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(commit.oid, forType: .string)
                                    }
                                }
                            }
                            if model.hasMore { Button("Cargar 100 commits más") { model.loadMore() }.padding().disabled(model.busy) }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: model.commits) {
            let commits = model.commits
            let layout = await Task.detached { GraphLayout.make(commits) }.value
            if !Task.isCancelled { graph = layout }
        }
    }
    private var working: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(model.stagedView ? "Cambios preparados" : "Cambios pendientes").font(.title2.bold())
                Spacer()
                Text("\(model.files.count) archivos").foregroundStyle(.secondary)
            }
            Text(model.stagedView ? "El commit incluye solo el contenido del índice." : "Selecciona archivos para revisar y preparar sus cambios.")
                .font(.caption).foregroundStyle(.secondary)
            List(model.files) { file in
                HStack {
                    Button(file.name) { model.loadDiff(id: file.id) }.buttonStyle(.plain).lineLimit(1)
                    Spacer()
                    Text(file.status).font(.caption.monospaced()).foregroundStyle(file.conflict ? .orange : .secondary)
                    Button(model.stagedView ? "Despreparar" : "Preparar") {
                        let paths = [file.path] + (file.oldPath.map { [$0] } ?? [])
                        model.mutate(model.stagedView ? .unstage(paths) : .stage(paths))
                    }.disabled(!model.mutable)
                }.padding(.vertical, 3)
            }.listStyle(.inset)
            if model.stagedView {
                Text("Mensaje del commit").font(.headline)
                TextEditor(text: $commitMessage).font(.body.monospaced()).frame(height: 100)
                    .accessibilityLabel("Mensaje del commit")
                Button("Crear commit", systemImage: "checkmark.seal") {
                    model.mutate(.commit(commitMessage))
                }.buttonStyle(.borderedProminent)
                    .disabled(!model.mutable || model.files.isEmpty || commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(16)
    }
}
