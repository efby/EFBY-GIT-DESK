import SwiftUI
import EfbyGitDeskDomain

struct AmendConfirmation: View {
    @Bindable var model: DeskModel
    let plan: AmendPlan
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(plan.destination == nil ? "Confirmar edición local" : "Confirmar reescritura publicada").font(.title2.bold())
            LabeledContent("Rama", value: plan.branch)
            LabeledContent("HEAD anterior", value: String(plan.oldHead.prefix(12)))
            if let destination = plan.destination { LabeledContent("Destino", value: destination) }
            Text(plan.newMessage).font(.body.monospaced()).textSelection(.enabled).frame(maxHeight: 160)
            Text("Recuperación: \(plan.recoveryReference)").font(.caption.monospaced()).textSelection(.enabled)
            Text("El plan expira en 60 segundos. Si HEAD, el índice o el remoto cambian, la operación se detiene.")
                .font(.caption).foregroundStyle(.secondary)
            if model.busy { ProgressView(model.status) }
            HStack {
                Button("Cancelar") { model.cancelPlan() }.disabled(model.busy)
                Spacer()
                Button(plan.destination == nil ? "Editar mensaje" : "Reescribir punta y publicar", role: .destructive) { model.executePlan() }
                    .buttonStyle(.borderedProminent).disabled(model.busy)
            }
        }.padding(26).frame(width: 640).interactiveDismissDisabled(model.busy)
    }
}
