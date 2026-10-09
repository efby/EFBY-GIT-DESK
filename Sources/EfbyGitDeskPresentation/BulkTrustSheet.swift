import SwiftUI
import EfbyGitDeskDomain

struct BulkTrustSheet: View {
    let repositories: [Repository]
    let confirm: ([String]) -> Void
    @Environment(\.dismiss) private var dismiss

    private var pendingCheckoutCount: Int { repositories.filter(\.pendingCheckout).count }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Confiar en todos").font(.title2.bold())
            Text("Revisa los \(repositories.count) repositorios que recibirán confianza. Se volverá a comprobar la identidad de cada uno; los que hayan cambiado o solo admitan inspección se omitirán con un resultado visible.")
            Label("Git puede ejecutar hooks, filtros y auxiliares configurados. El terminal tendrá tus permisos en estos repositorios.", systemImage: "exclamationmark.shield")
                .foregroundStyle(.orange)
            if pendingCheckoutCount > 0 {
                Text("\(pendingCheckoutCount) clones pendientes intentarán materializar sus archivos después de recibir confianza.")
                    .foregroundStyle(.orange)
            }
            List(repositories) { repository in
                VStack(alignment: .leading, spacing: 2) {
                    Text(repository.name).font(.body.weight(.medium))
                    Text(repository.path).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                }
            }
            HStack {
                Button("Cancelar", role: .cancel) { dismiss() }
                Spacer()
                Button("Confiar en \(repositories.count) repositorios") {
                    let ids = repositories.map(\.id)
                    confirm(ids)
                }
                .buttonStyle(.borderedProminent)
                .disabled(repositories.isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 600, minHeight: 420)
    }
}
