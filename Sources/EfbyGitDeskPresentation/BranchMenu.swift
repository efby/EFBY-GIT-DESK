import SwiftUI
import AppKit

struct BranchMenu: View {
    @Bindable var model: DeskModel
    var body: some View {
        Menu {
            Section("Ramas locales") {
                ForEach(model.branches.filter { !$0.remote }) { branch in
                    Menu(branch.name, systemImage: branch.current ? "checkmark" : "arrow.triangle.branch") {
                        Button("Cambiar a esta rama") { model.mutate(.checkout(branch.name)) }
                            .disabled(!model.mutable || branch.current)
                        Button("Copiar nombre") { copy(branch.name) }
                        Button("Borrar rama integrada", role: .destructive) { model.mutate(.deleteBranch(branch.name)) }
                            .disabled(!model.mutable || branch.current)
                    }
                }
            }
            Section("Ramas remotas") {
                ForEach(model.branches.filter(\.remote)) { branch in
                    Menu(branch.name, systemImage: "network") {
                        Button("Copiar nombre") { copy(branch.name) }
                    }
                }
            }
            if model.branches.isEmpty { Text("Sin ramas disponibles") }
        } label: {
            Label("Ramas (\(model.branches.count))", systemImage: "arrow.triangle.branch")
        }.fixedSize().help("Consultar ramas locales y remotas; cambiar o borrar una rama local")
    }
    private func copy(_ name: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(name, forType: .string)
    }
}
