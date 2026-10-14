import SwiftUI

struct FolderScanProgressSheet: View {
    let progress: FolderScanProgressModel
    let cancel: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Escaneando \(progress.rootName)").font(.title2.bold())
            Text(progress.phase).foregroundStyle(.secondary)
            if !progress.finished {
                ProgressView().controlSize(.regular)
                if progress.importingTotal > 0 {
                    Text("Proyecto \(progress.importingIndex) de \(progress.importingTotal): \(progress.importingName)")
                        .lineLimit(1)
                } else {
                    Text("Carpetas revisadas: \(progress.visited) · encontrados: \(progress.discovered)")
                }
            }
            if progress.cancelled {
                Label("Escaneo interrumpido. Puedes volver a intentarlo.", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
            if let failure = progress.failure {
                Label(failure, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
            }
            if let issues = progress.issueSummary {
                Text(issues).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            }
            List(progress.entries) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name).font(.body.weight(.medium))
                    Text(entry.path).font(.caption).foregroundStyle(.secondary)
                }
            }
            HStack {
                Spacer()
                if progress.finished {
                    Button("Cerrar") { dismiss() }.buttonStyle(.borderedProminent)
                } else {
                    Button("Cancelar") { cancel() }.keyboardShortcut(.cancelAction)
                }
            }
        }
        .padding(20)
        .frame(minWidth: 620, minHeight: 420)
        .interactiveDismissDisabled(!progress.finished)
    }
}
