import SwiftUI

struct WorkspaceTabs: View {
    @Bindable var model: DeskModel
    var body: some View {
        HStack(spacing: 16) {
            Picker("Vista del repositorio", selection: $model.workspaceSection) {
                Text("Pendientes (\(model.snapshot.files.filter(\.unstaged).count))")
                    .tag(WorkspaceSection.pending).disabled(model.repository?.trusted != true)
                Text("Preparados (\(model.snapshot.files.filter(\.staged).count))")
                    .tag(WorkspaceSection.staged).disabled(model.repository?.trusted != true)
                Text("Historial").tag(WorkspaceSection.history)
            }.pickerStyle(.segmented).labelsHidden().frame(maxWidth: 560)
                .accessibilityIdentifier("workspaceTabs")
            Spacer(minLength: 0)
            BranchMenu(model: model)
        }.padding(.horizontal, 12).padding(.vertical, 10)
    }
}
