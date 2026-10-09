import SwiftUI
import EfbyGitDeskApplication

struct BulkRepositoryProgressSheet: View {
    let progress: BulkRepositoryProgress
    let cancel: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(progress.kind.rawValue) de todos").font(.title2.bold())
            Text("\(progress.completed) completados · \(progress.skipped) omitidos · \(progress.failed) con error")
                .foregroundStyle(.secondary)
            if let current = progress.current, !progress.finished {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("Procesando: \(current)").lineLimit(2)
                }
                .accessibilityElement(children: .combine)
            } else if !progress.finished {
                ProgressView("Preparando repositorios…").controlSize(.small)
            }
            if progress.cancelled {
                Label("Operación interrumpida. Revisa el estado real antes de repetir.", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
            if let failure = progress.failure {
                Label(failure, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }
            ScrollViewReader { scroll in
                List(progress.entries) { entry in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: icon(entry.result))
                            .foregroundStyle(color(entry.result))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.name + (entry.remote.map { " · \($0)" } ?? ""))
                                .font(.body.weight(.medium))
                            Text(entry.path).font(.caption).foregroundStyle(.secondary)
                            Text(entry.detail).font(.caption).textSelection(.enabled)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
                .onChange(of: progress.entries.count) { _, _ in
                    if let id = progress.entries.last?.id { scroll.scrollTo(id, anchor: .bottom) }
                }
            }
            HStack {
                Spacer()
                if progress.finished {
                    Button("Cerrar") { dismiss() }.buttonStyle(.borderedProminent)
                } else {
                    Button(progress.cancellationRequested ? "Cancelando…" : "Cancelar operación") {
                        progress.cancellationRequested = true
                        cancel()
                    }
                    .disabled(progress.cancellationRequested)
                }
            }
        }
        .padding(20)
        .frame(minWidth: 640, minHeight: 420)
        .interactiveDismissDisabled(!progress.finished)
    }

    private func icon(_ result: BulkRepositoryReport.Entry.Result) -> String {
        switch result {
        case .completed: "checkmark.circle.fill"
        case .skipped: "minus.circle"
        case .failed: "exclamationmark.triangle.fill"
        }
    }
    private func color(_ result: BulkRepositoryReport.Entry.Result) -> Color {
        switch result {
        case .completed: .green
        case .skipped: .secondary
        case .failed: .red
        }
    }
}
