import SwiftUI
import AppKit
import EfbyGitDeskApplication
import EfbyGitDeskDomain

public struct WorkspaceView: View {
    @Bindable private var model: DeskModel
    @State private var connections = false
    @State private var cloning = false
    @State private var newBranch = false
    @State private var pushing = false
    @State private var trusting = false
    @Environment(\.scenePhase) private var phase
    public init(model: DeskModel) { self.model = model }
    public var body: some View {
        ComparisonWorkspaceLayer(model: model) {
            PersistentSplitView(width: $model.sidebarWidth, anchoredLeading: true, minimum: 210, maximum: 340, otherMinimum: 710) {
                RepositorySidebar(model: model)
            } second: {
                VStack(spacing: 0) {
                    RepositoryTabs(model: model)
                    topBar
                    Divider()
                    if let repository = model.repository {
                        if !repository.trusted {
                            HStack {
                                Label("Inspección segura · Confianza pendiente", systemImage: "lock.shield")
                                Spacer()
                                Button("Confiar y habilitar operaciones") { trusting = true }.buttonStyle(.borderedProminent)
                            }.padding(12).background(.orange.opacity(0.12))
                        } else if !model.remoteNames.isEmpty && !model.remoteSupported {
                            Label("Este remoto no es Bitbucket Cloud. Historial y operaciones locales disponibles.", systemImage: "info.circle")
                                .font(.caption).frame(maxWidth: .infinity, alignment: .leading).padding(10)
                        }
                        if let reason = repository.inspectionReason {
                            Label(reason, systemImage: "info.circle").font(.caption).padding(10)
                        } else if repository.linkedWorktree {
                            Label("Worktree vinculado: solo inspección en este MVP.", systemImage: "info.circle").font(.caption).padding(10)
                        }
                        RepositoryWorkArea(model: model)
                        if model.terminalVisible {
                            Divider()
                            TerminalPane(model: model).frame(height: model.terminalHeight)
                        }
                    } else { welcome }
                    Divider()
                    HStack(spacing: 10) {
                        if model.busy { ProgressView().controlSize(.small); Button("Cancelar") { model.cancelOperation() } }
                        Text(model.status).font(.caption).lineLimit(2).textSelection(.enabled)
                        Spacer()
                        if !model.snapshot.upstream.isEmpty {
                            Text("↑ \(model.snapshot.ahead.map(String.init) ?? "?")  ↓ \(model.snapshot.behind.map(String.init) ?? "?") · caché local")
                                .font(.caption.monospaced()).foregroundStyle(.secondary)
                        }
                    }.padding(.horizontal, 14).padding(.vertical, 8)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .windowBackgroundColor))
            }
        }

        .tint(.teal).preferredColorScheme(.dark)
        .frame(minWidth: 1120, minHeight: 700)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 22, height: 22)
                    .accessibilityHidden(true)
            }
            if model.selectedFile == nil {
                ToolbarItemGroup {
                    Button("Abrir carpeta", systemImage: "folder.badge.plus") { model.chooseRepository() }.keyboardShortcut("o")
                    Button("Clonar", systemImage: "square.and.arrow.down") { cloning = true }
                    Button("Conexiones", systemImage: "network") { connections = true }
                }
            }
        }
        .task {
            await model.load()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                if !model.busy && model.repository?.trusted == true && phase == .active { model.refresh() }
            }
        }
        .onChange(of: model.sidebarWidth) { _, _ in model.persistLayout() }
        .onChange(of: model.selectedID) { _, value in if let value { model.select(value) } }
        .onChange(of: phase) { _, value in if value == .active && !model.busy { model.refresh() } }
        .onChange(of: model.remote) { _, _ in if !model.busy { model.refresh() } }
        .alert("La operación requiere atención", isPresented: Binding(
            get: { model.error != nil }, set: { if !$0 { model.error = nil } }
        )) { Button("Aceptar") { model.error = nil } } message: { Text(model.error ?? "") }
        .alert("¿Confías en este repositorio?", isPresented: $trusting) {
            Button("Cancelar", role: .cancel) {}
            Button("Confiar") { model.trust() }
        } message: {
            Text("\(model.repository?.path ?? "")\n\nGit puede ejecutar hooks, filtros y auxiliares configurados. El terminal tendrá tus permisos. Abrir o autenticar un repositorio no concede esta confianza.")
        }
        .sheet(isPresented: $connections) { ConnectionsSheet(model: model) }
        .sheet(isPresented: $cloning) { CloneSheet(model: model) }
        .sheet(isPresented: $newBranch) { BranchSheet(model: model) }
        .sheet(isPresented: $pushing) { PushSheet(model: model) }
        .sheet(item: $model.bulkProgress) { progress in
            BulkRepositoryProgressSheet(progress: progress) { model.cancelOperation() }
        }
        .sheet(isPresented: $model.showAmend) { AmendSheet(model: model) }
        .sheet(item: $model.plan, onDismiss: { if !model.busy { model.cancelPlan(); model.unpause() } }) { plan in
            AmendConfirmation(model: model, plan: plan)
        }
    }
    private var topBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                if let repository = model.repository {
                    Text(Self.parentContext(for: repository.path))
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(repository.path)
                        .accessibilityLabel("Ubicación del proyecto: \(repository.path)")
                } else {
                    Text("Selecciona un proyecto").font(.headline)
                }
                Label(model.snapshot.branch.isEmpty ? "Sin rama" : model.snapshot.branch, systemImage: "arrow.triangle.branch")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if !model.remoteNames.isEmpty {
                Picker("Remoto", selection: $model.remote) { ForEach(model.remoteNames, id: \.self) { Text($0).tag($0) } }
                    .labelsHidden().frame(width: 120).help("Remoto seleccionado")
            }
            Button("Actualizar", systemImage: "arrow.clockwise") { model.refresh(forceHistory: true) }.disabled(model.busy)
            Button("Fetch", systemImage: "arrow.down.to.line") { model.mutate(.fetch(model.remote)) }.disabled(!model.mutable || !model.remoteSupported)
            Button("Pull", systemImage: "arrow.down") { model.mutate(.pull(model.remote)) }.disabled(!model.mutable || !model.remoteSupported)
            Button("Push", systemImage: "arrow.up") { pushing = true }.disabled(!model.mutable || !model.remoteSupported)
            Button("Rama", systemImage: "arrow.triangle.branch") { newBranch = true }.disabled(!model.mutable || model.snapshot.head.isEmpty)
            Button("Terminal", systemImage: "terminal") { model.terminalVisible.toggle(); model.persistLayout() }
                .keyboardShortcut("j").disabled(model.repository?.trusted != true)
        }.buttonStyle(.bordered).controlSize(.small).padding(12)
    }
    private static func parentContext(for path: String) -> String {
        let parent = URL(fileURLWithPath: path).deletingLastPathComponent()
        let components = parent.pathComponents.filter { $0 != "/" }
        let context = components.suffix(2).joined(separator: " / ")
        return context.isEmpty ? parent.path : context
    }
    private var welcome: some View {
        VStack(spacing: 22) {
            Image(systemName: "arrow.triangle.branch").font(.system(size: 58)).foregroundStyle(.teal).accessibilityHidden(true)
            Text("Tus proyectos, en una sola vista.").font(.largeTitle.bold())
            Text("Abre un proyecto o una carpeta para encontrar todos sus repositorios Git.\nOrganízalos por carpetas, explora su historial y prepara cambios.")
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
            HStack {
                Button("Abrir carpeta") { model.chooseRepository() }.buttonStyle(.borderedProminent)
                Button("Clonar desde Bitbucket") { cloning = true }.buttonStyle(.bordered)
            }
            Label("Cada repositorio comienza en modo de inspección segura.", systemImage: "lock.shield").font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
