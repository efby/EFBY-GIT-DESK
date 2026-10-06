import SwiftUI

struct AmendSheet: View {
    @Bindable var model: DeskModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Editar mensaje de HEAD").font(.title2.bold())
            Text("Solo cambia el mensaje. El árbol, los padres y el autor se verifican y se conserva una referencia de recuperación.")
                .foregroundStyle(.secondary)
            TextEditor(text: $model.amendText).font(.body.monospaced()).frame(height: 170).accessibilityLabel("Nuevo mensaje de HEAD")
            Toggle("Publicar la edición en el remoto", isOn: $model.publishAmend).disabled(!model.remoteSupported)
            if model.publishAmend {
                Label("Cambiará el SHA y se reescribirá la punta de \(model.remote)/\(model.snapshot.branch).", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange).font(.caption)
            }
            HStack {
                Button("Cancelar") { model.unpause(); dismiss() }
                Spacer()
                Button("Preparar y revisar plan") { model.prepareAmend() }.buttonStyle(.borderedProminent)
                    .disabled(model.busy || model.amendText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(26).frame(width: 600)
    }
}
