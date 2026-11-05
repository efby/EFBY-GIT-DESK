import Foundation
import Testing
import EfbyGitDeskApplication
import EfbyGitDeskDomain
import EfbyGitDeskInfrastructure
@testable import EfbyGitDeskPresentation

@MainActor struct AuditPresentationTests {
    @Test func allFilesFailureKeepsChangedFilesVisible() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let repository = Repository(path: folder.path, gitDirectory: folder.path + "/.git",
                                    commonDirectory: folder.path + "/.git", name: "Fixture", trusted: true)
        let changed = FileChange(path: Data("changed.py".utf8), status: "M", unstaged: true)
        let registry = try SQLiteRegistry(path: folder.appendingPathComponent("catalog.sqlite").path)
        let service = DeskService(git: AllFilesFailureStub(changed: changed), registry: registry,
                                  cloud: BitbucketClient(vault: KeychainVault()))
        let model = DeskModel(service: service, terminalFactory: { PTYTerminal(shell: "/bin/sh", login: false) })
        model.repositories = [repository]
        model.selectedID = repository.id
        model.workingView = true
        model.setShowAllFiles(true)
        try await waitForModel("inventario tras fallo de Todos los archivos", model: model) {
            !model.filesLoading && !model.visibleFiles.isEmpty
        }
        #expect(model.files == [changed])
        #expect(model.visibleFiles == [changed])
        #expect(!model.showAllFiles)
        #expect(model.error?.contains("Se muestran los archivos modificados") == true)
    }

    @Test func restoreStateIsUnavailableWhenTrackedWorkIsPending() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let repository = Repository(path: "/private/tmp/audit-restore", gitDirectory: "/private/tmp/audit-restore/.git",
                                    commonDirectory: "/private/tmp/audit-restore/.git", name: "Fixture", trusted: true)
        let model = DeskModel(service: DeskService(git: AllFilesFailureStub(changed: FileChange(path: Data("a".utf8), status: "M")),
                                                   registry: try SQLiteRegistry(path: folder.appendingPathComponent("catalog.sqlite").path),
                                                   cloud: BitbucketClient(vault: KeychainVault())),
                              terminalFactory: { PTYTerminal(shell: "/bin/sh", login: false) })
        model.repositories = [repository]
        model.selectedID = repository.id
        model.remoteSupported = true
        model.snapshot = RepositorySnapshot(branch: "main", upstream: "origin/main", ahead: 0,
                                            files: [FileChange(path: Data("changed.py".utf8), status: "M", unstaged: true)])
        #expect(!model.canRestoreRepositoryState)
        #expect(model.restoreRepositoryStateUnavailableReason?.contains("cambios locales") == true)
        model.snapshot.files = [FileChange(path: Data("untracked.py".utf8), status: "?", unstaged: true)]
        #expect(model.canRestoreRepositoryState)
        model.snapshot.ahead = nil
        #expect(!model.canRestoreRepositoryState)
        #expect(model.restoreRepositoryStateUnavailableReason?.contains("No se pudo verificar") == true)
    }

    @Test func failedRefreshClearsStaleComparison() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let repository = Repository(path: folder.path, gitDirectory: folder.path + "/.git",
                                    commonDirectory: folder.path + "/.git", name: "Fixture", trusted: true)
        let changed = FileChange(path: Data("changed.py".utf8), status: "M", unstaged: true)
        let service = DeskService(git: AllFilesFailureStub(changed: changed),
                                  registry: try SQLiteRegistry(path: folder.appendingPathComponent("catalog.sqlite").path),
                                  cloud: BitbucketClient(vault: KeychainVault()))
        let model = DeskModel(service: service, terminalFactory: { PTYTerminal(shell: "/bin/sh", login: false) })
        model.repositories = [repository]; model.selectedID = repository.id; model.workingView = true
        model.setShowAllFiles(true)
        try await waitForModel("inventario antes del diff", model: model) {
            !model.filesLoading && !model.visibleFiles.isEmpty
        }
        model.selectedFile = changed.id; model.openDocument = changed
        model.comparison = FileComparison(before: "old", after: "stale", beforeLabel: "A", afterLabel: "B", patch: "old")
        model.loadDiff(id: changed.id)
        #expect(model.diffLoading)
        try await waitForModel("recarga del diff", model: model) {
            !model.diffLoading
        }
        #expect(model.comparison == nil)
        #expect(model.error?.contains("No se pudo actualizar la comparación") == true)
    }

    private func waitForModel(_ phase: String, model: DeskModel, until complete: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(30))
        while !complete() {
            guard ContinuousClock.now < deadline else {
                throw DeskError("Tiempo agotado al esperar \(phase): archivos=\(model.visibleFiles.count), " +
                                "cargandoArchivos=\(model.filesLoading), cargandoDiff=\(model.diffLoading), " +
                                "todos=\(model.showAllFiles), error=\(model.error ?? "ninguno")")
            }
            try await Task.sleep(for: .milliseconds(20))
        }
    }
}

private struct AllFilesFailureStub: GitRepositoryPort {
    let changed: FileChange
    func executablePath() async throws -> String { throw DeskError("Sin usar") }
    func configureExecutable(path: String?) async throws { throw DeskError("Sin usar") }
    func version() async throws -> String { throw DeskError("Sin usar") }
    func discover(path: String) async throws -> Repository { throw DeskError("Sin usar") }
    func snapshot(_ repository: Repository) async throws -> RepositorySnapshot { throw DeskError("Sin usar") }
    func branches(_ repository: Repository) async throws -> [Branch] { throw DeskError("Sin usar") }
    func history(_ repository: Repository, tips: [String], offset: Int, search: String) async throws -> [Commit] { throw DeskError("Sin usar") }
    func comparisonOrder(_ repository: Repository, tips: [String], selected: [String]) async throws -> [String] { throw DeskError("Sin usar") }
    func changes(_ repository: Repository, context: DiffContext) async throws -> [FileChange] { [changed] }
    func allFiles(_ repository: Repository, context: DiffContext) async throws -> [FileChange] { throw DeskError("Inventario demasiado grande") }
    func declarationHits(_ repository: Repository, context: DiffContext, names: [String]) async throws -> [DeclarationHit] { throw DeskError("Sin usar") }
    func diff(_ repository: Repository, context: DiffContext, file: FileChange) async throws -> String { throw DeskError("Sin usar") }
    func fileComparison(_ repository: Repository, context: DiffContext, file: FileChange) async throws -> FileComparison { throw DeskError("Sin usar") }
    func execute(_ action: GitAction, repository: Repository, profile: ConnectionProfile?) async throws -> String { throw DeskError("Sin usar") }
    func clone(source: String, destination: String, profile: ConnectionProfile?) async throws -> Repository { throw DeskError("Sin usar") }
    func materializeClone(_ repository: Repository) async throws { throw DeskError("Sin usar") }
    func prepareAmend(_ repository: Repository, message: String, publish: Bool, remote: String,
                      profile: ConnectionProfile?) async throws -> AmendPlan { throw DeskError("Sin usar") }
    func executeAmend(_ plan: AmendPlan, profile: ConnectionProfile?) async throws -> String { throw DeskError("Sin usar") }
    func remotes(_ repository: Repository) async throws -> [String] { throw DeskError("Sin usar") }
    func legacyBitbucketSSHHostNeedsUpdate(_ repository: Repository, remote: String) async throws -> Bool { false }
    func migrateLegacyBitbucketSSHRemote(_ repository: Repository, remote: String) async throws -> Bool { false }
    func remoteSupported(_ repository: Repository, remote: String) async -> Bool { false }
    func message(_ repository: Repository, oid: String) async throws -> String { throw DeskError("Sin usar") }
}
