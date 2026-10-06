import SwiftUI
import EfbyGitDeskDomain

struct BranchSidebar: View {
    @Bindable var model: DeskModel
    var body: some View {
        List {
            Section("Área de trabajo") {
                Button { model.showWorking(staged: false) } label: {
                    Label("Pendientes (\(model.snapshot.files.filter(\.unstaged).count))", systemImage: "pencil")
                }.disabled(model.repository?.trusted != true)
                Button { model.showWorking(staged: true) } label: {
                    Label("Preparados (\(model.snapshot.files.filter(\.staged).count))", systemImage: "checkmark.circle")
                }.disabled(model.repository?.trusted != true)
                Button("Historial", systemImage: "clock") { model.workingView = false; model.loadFiles() }
            }
            Section("Ramas locales") {
                ForEach(model.branches.filter { !$0.remote }) { branch in
                    Label(branch.name, systemImage: branch.current ? "checkmark" : "arrow.triangle.branch")
                        .font(.caption).textSelection(.enabled)
                        .contextMenu {
                            Button("Cambiar a esta rama") { model.mutate(.checkout(branch.name)) }.disabled(!model.mutable || branch.current)
                            Button("Borrar rama integrada", role: .destructive) { model.mutate(.deleteBranch(branch.name)) }.disabled(!model.mutable || branch.current)
                        }
                }
            }
            Section("Ramas remotas") {
                ForEach(model.branches.filter(\.remote)) { branch in
                    Label(branch.name, systemImage: "network").font(.caption).textSelection(.enabled)
                }
            }
        }.listStyle(.sidebar)
    }
}
