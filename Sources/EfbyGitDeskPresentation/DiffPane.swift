import SwiftUI
import AppKit

struct DiffPane: View {
    @Bindable var model: DeskModel
    @State private var collapsed: Set<String> = []
    @State private var treeNodes: [ComparisonFileNode] = []
    @State private var restoredRepositoryID: String?
    @State private var expansionVersion = 0
    @State private var expansionSave: Task<Void, Never>?
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text(title).font(.headline)
                    Spacer()
                }
                ForEach(Array(model.orderedComparison.reversed()), id: \.self) { oid in
                    if let commit = model.commitDetails(oid) {
                        ComparisonCommitCard(commit: commit, revisionLabel: model.selectedOIDs.count == 2
                            ? (oid == model.orderedComparison.first ? "A · Inferior · Origen" : "B · Superior · Destino") : "Commit")
                    }
                }
                if model.selectedOIDs.count == 1,
                   let commit = model.commitDetails(model.selectedOIDs[0]), commit.parents.count > 1 {
                    Picker("Padre del merge", selection: $model.parentIndex) {
                        ForEach(commit.parents.indices, id: \.self) { Text("Padre \($0 + 1)").tag($0) }
                    }.onChange(of: model.parentIndex) { _, _ in model.loadFiles() }
                }
                if model.context != nil {
                    Toggle("Todos los archivos", isOn: Binding(
                        get: { model.showAllFiles }, set: { model.setShowAllFiles($0) }
                    )).toggleStyle(.checkbox).help("Mostrar también archivos sin cambios para revisar el código")
                        .accessibilityIdentifier("showAllComparisonFiles")
                    Text(model.filesLoading ? "Consultando archivos…" : "\(model.files.count) modificados · \(model.visibleFiles.count) visibles")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Button("Editar mensaje de HEAD", systemImage: "pencil.line") { model.beginAmend() }
                    .disabled(!model.mutable || model.snapshot.head.isEmpty)
            }.padding(14)
            Divider()
            if model.comparisonOrdering {
                ProgressView("Ordenando commits del historial…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.comparisonOrderFailed {
                ContentUnavailableView("No se pudo ordenar la comparación", systemImage: "exclamationmark.triangle",
                    description: Text("Quita un commit de la selección y vuelve a intentarlo."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.context == nil {
                ContentUnavailableView("Selecciona un commit", systemImage: "arrow.left.arrow.right",
                    description: Text("Selecciona dos para comparar sus árboles A→B. Los cambios locales se revisan por separado."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    Text("Haz clic en un archivo para ver sus diferencias.")
                        .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 12).padding(.vertical, 6)
                    if model.visibleFiles.isEmpty && !model.filesLoading {
                        ContentUnavailableView("Sin archivos", systemImage: "doc", description: Text("No hay archivos en esta selección."))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if restoredRepositoryID == model.selectedID { fileList }
                    else { ProgressView("Restaurando carpetas…").frame(maxWidth: .infinity, maxHeight: .infinity) }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
            .task(id: model.fileInventoryRevision) {
                let files = model.visibleFiles
                let nodes = await Task.detached { ComparisonFileNode.make(files) }.value
                if !Task.isCancelled { treeNodes = nodes }
            }
            .task(id: model.selectedID) {
                collapsed = []; restoredRepositoryID = nil
                let version = expansionVersion
                guard let id = model.selectedID else { return }
                let key = FolderExpansionPreference.key(scope: "comparison", repositoryID: id)
                let saved = try? await model.service.registry.preference(key)
                guard !Task.isCancelled, model.selectedID == id, expansionVersion == version else { return }
                collapsed = FolderExpansionPreference.decode(saved)
                restoredRepositoryID = id
            }
    }
    private var fileList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 1) {
                Button(allFoldersExpanded ? "Colapsar todo" : "Expandir todo") {
                    updateCollapsed(FolderExpansionPreference.toggleAll(collapsed: collapsed, visible: visibleFolderIDs))
                }
                .disabled(visibleFolderIDs.isEmpty)
                .buttonStyle(.plain).padding(.bottom, 3)
                ComparisonTreeRows(model: model, nodes: treeNodes, collapsed: collapsed, toggleFolder: toggleFolder)
            }.padding(.horizontal, 12).padding(.vertical, 6).frame(maxWidth: .infinity, alignment: .leading)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var visibleFolderIDs: Set<String> { treeNodes.reduce(into: Set<String>()) { $0.formUnion($1.folderIDs) } }
    private var allFoldersExpanded: Bool { FolderExpansionPreference.allExpanded(collapsed: collapsed, visible: visibleFolderIDs) }
    private func toggleFolder(_ id: String) {
        var updated = collapsed
        if !updated.insert(id).inserted { updated.remove(id) }
        updateCollapsed(updated)
    }
    private func updateCollapsed(_ updated: Set<String>) {
        guard let id = model.selectedID, updated != collapsed else { return }
        collapsed = updated; expansionVersion += 1
        guard let value = FolderExpansionPreference.encode(updated) else { return }
        let previous = expansionSave
        let service = model.service
        let key = FolderExpansionPreference.key(scope: "comparison", repositoryID: id)
        expansionSave = Task {
            await previous?.value
            let registry = await service.registry
            try? await registry.setPreference(key, value: value)
        }
    }

    private var title: String {
        if model.workingView { return model.stagedView ? "HEAD → Índice" : "Índice → Working tree" }
        return model.selectedOIDs.count == 2 ? "Comparación A → B" : "Detalle del commit"
    }
}
