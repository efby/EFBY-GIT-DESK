import Foundation
import Observation
import EfbyGitDeskApplication

@MainActor @Observable final class BulkRepositoryProgress: Identifiable {
    let id = UUID()
    let kind: BulkRepositoryReport.Kind
    var current: String?
    var entries: [BulkRepositoryReport.Entry] = []
    var finished = false
    var cancelled = false
    var cancellationRequested = false
    var failure: String?

    init(kind: BulkRepositoryReport.Kind) { self.kind = kind }

    var completed: Int { entries.filter { $0.result == .completed }.count }
    var skipped: Int { entries.filter { $0.result == .skipped }.count }
    var failed: Int { entries.filter { $0.result == .failed }.count }

    func apply(_ event: BulkRepositoryProgressEvent) {
        switch event {
        case .started(let repository, let remote):
            current = repository.name + (remote.map { " · \($0)" } ?? "")
        case .finished(let entry):
            entries.append(entry)
            current = nil
        }
    }

    func finish(_ report: BulkRepositoryReport) {
        entries = report.entries
        cancelled = report.cancelled
        current = nil
        finished = true
    }

    func fail(_ error: Error) {
        failure = error.localizedDescription
        current = nil
        finished = true
    }
}
