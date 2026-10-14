import Foundation
import Observation
import EfbyGitDeskApplication

@MainActor @Observable final class FolderScanProgressModel: Identifiable {
    let id = UUID()
    let rootName: String
    var phase = "Preparando escaneo…"
    var discovered = 0
    var visited = 0
    var importingIndex = 0
    var importingTotal = 0
    var importingName = ""
    var entries: [FolderScanEntry] = []
    var finished = false
    var cancelled = false
    var failure: String?
    var issueSummary: String?

    init(rootPath: String) {
        rootName = URL(fileURLWithPath: rootPath).lastPathComponent
    }

    func apply(_ event: FolderScanProgressEvent) {
        switch event {
        case .scanning(let currentPath, let discovered, let visited):
            phase = "Buscando repositorios…"
            self.discovered = discovered
            self.visited = visited
            importingName = URL(fileURLWithPath: currentPath).lastPathComponent
        case .importing(let path, let name, let index, let total):
            phase = "Registrando proyectos…"
            importingIndex = index
            importingTotal = total
            importingName = name
            discovered = max(discovered, total)
            if entries.contains(where: { $0.path == path }) == false {
                entries.append(FolderScanEntry(path: path, name: name, detail: "Registrado", result: .completed))
            }
        }
    }

    func finish(issues: [String], cancelled: Bool) {
        self.cancelled = cancelled
        if !issues.isEmpty { issueSummary = issues.prefix(12).joined(separator: "\n") }
        finished = true
        phase = cancelled ? "Escaneo interrumpido" : "Escaneo completado"
    }

    func fail(_ error: Error) {
        failure = error.localizedDescription
        finished = true
        phase = "Escaneo con error"
    }
}
