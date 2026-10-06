import SwiftUI

struct PushSheet: View {
    @Bindable var model: DeskModel
    @Environment(\.dismiss) private var dismiss
    @State private var upstream = true
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Publicar rama").font(.title2.bold())
            LabeledContent("Repositorio", value: model.repository?.name ?? "")
            LabeledContent("Rama local", value: model.snapshot.branch)
            LabeledContent("Remoto", value: model.remote)
            LabeledContent("Destino", value: "refs/heads/" + model.snapshot.branch)
            Text(model.snapshot.head).font(.caption.monospaced()).textSelection(.enabled)
            Toggle("Establecer upstream", isOn: $upstream)
            Text("Push normal. Si el remoto avanzó, la operación será rechazada.").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Cancelar") { dismiss() }
                Spacer()
                Button("Publicar") {
                    model.mutate(.push(remote: model.remote, branch: model.snapshot.branch, setUpstream: upstream)); dismiss()
                }.buttonStyle(.borderedProminent).disabled(!model.mutable || model.snapshot.head.isEmpty)
            }
        }.padding(26).frame(width: 540)
    }
}
