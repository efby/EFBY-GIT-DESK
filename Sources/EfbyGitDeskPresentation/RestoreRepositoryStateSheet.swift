import SwiftUI
import EfbyGitDeskDomain

struct RestoreRepositoryStateSheet: View {
    let commit: Commit
    @Bindable var model: DeskModel
    @Environment(\.dismiss) private var dismiss
    @State private var showFinalConfirmation = false

    var body: some View {
        let preview = RestoreRepositoryStateMessage.compose(
            userInput: model.restoreStateTicket,
            shortOID: commit.shortOID
        )
        VStack(alignment: .leading, spacing: 18) {
            Text("Restaurar estado del repositorio").font(.title2.bold())
            Text("El contenido del commit \(commit.shortOID) pasará a ser el del árbol de trabajo. Después se creará un commit nuevo encima del HEAD actual y se publicará en el remoto.")
                .foregroundStyle(.secondary)
            Label("Los commits que ya están por encima de \(commit.shortOID) no se borran: siguen en el historial. El commit de restauración quedará como el último y el push actualizará la punta de la rama.", systemImage: "clock.arrow.circlepath")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Identificador o mensaje del commit")
                .font(.headline)
            TextField("PDD-XXXX o IDS-XXXX", text: $model.restoreStateTicket)
                .textFieldStyle(.roundedBorder)
            Text("Mensaje resultante")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(preview.isEmpty ? "—" : preview)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            Label("Solo disponible sin commits locales pendientes de publicar.", systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button("Cancelar") { model.restoreStateTarget = nil; dismiss() }
                Spacer()
                Button("Continuar…", role: .destructive) {
                    showFinalConfirmation = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.busy || model.restoreStateTicket.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(26)
        .frame(width: 520)
        .alert("¿Restaurar este commit y dejarlo como el último?", isPresented: $showFinalConfirmation) {
            Button("Cancelar", role: .cancel) {}
            Button("Sí, restaurar y publicar", role: .destructive) {
                model.confirmRestoreRepositoryState()
                dismiss()
            }
        } message: {
            Text(restoreConfirmationMessage)
        }
    }

    private var restoreConfirmationMessage: String {
        let head = model.snapshot.head
        let headLabel = head.isEmpty ? "HEAD actual" : String(head.prefix(8))
        return """
        Vas a restaurar el estado de \(commit.shortOID) («\(commit.message)»).

        Se conservan todos los commits posteriores a ese punto en el historial. Se añadirá un commit nuevo encima de \(headLabel) con el árbol de \(commit.shortOID) y se publicará en \(model.remote)/\(model.snapshot.branch), dejando esa restauración como la punta de la rama en local y en el remoto.

        Esta acción no se puede deshacer desde la aplicación.
        """
    }
}
