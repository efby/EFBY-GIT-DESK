import Foundation
import EfbyGitDeskDomain

public actor DeskService {
    public let git: any GitRepositoryPort
    public let registry: any RegistryPort
    public let cloud: any HostingProviderPort
    private let discovery: (any FolderDiscoveryPort)?
    private let gate = OperationGate()
    private var plans: [UUID: AmendPlan] = [:]
    public init(git: any GitRepositoryPort, registry: any RegistryPort, cloud: any HostingProviderPort, discovery: (any FolderDiscoveryPort)? = nil) {
        self.git = git; self.registry = registry; self.cloud = cloud; self.discovery = discovery
    }
    public func open(path: String) async throws -> Repository {
        var result = try await git.discover(path: path)
        if let saved = try await registry.repositories().first(where: { $0.path == result.path }) {
            result.trusted = saved.trusted && saved.gitDirectory == result.gitDirectory && saved.commonDirectory == result.commonDirectory && saved.identity != nil && saved.identity == result.identity; result.favorite = saved.favorite; result.group = saved.group
            result.pendingCheckout = saved.pendingCheckout
        }
        result.lastOpened = .now
        try await registry.save(result)
        return result
    }
    public func openFolder(path: String) async throws -> FolderOpenResult {
        guard let discovery else {
            let repository = try await open(path: path)
            return FolderOpenResult(root: repository.path, repositories: [repository], issues: [])
        }
        let scan = try await discovery.scan(path: path)
        var opened: [Repository] = [], issues: [String] = []
        if scan.unreadableDirectories > 0 { issues.append("No se pudieron leer \(scan.unreadableDirectories) carpetas.") }
        if scan.externalLinks > 0 { issues.append("Se omitieron \(scan.externalLinks) enlaces a carpetas fuera de la ubicación elegida.") }
        for candidate in scan.paths {
            try Task.checkCancellation()
            do { opened.append(try await open(path: candidate)) }
            catch is CancellationError { throw CancellationError() }
            catch { issues.append(URL(fileURLWithPath: candidate).lastPathComponent + ": " + error.localizedDescription) }
        }
        if scan.paths.isEmpty {
            // Preserve opening a subfolder within an existing repository.
            do { opened = [try await open(path: path)] }
            catch is CancellationError { throw CancellationError() }
            catch { issues.append("No se encontraron repositorios Git en esta carpeta ni en sus subcarpetas.") }
        }
        if !opened.isEmpty {
            var roots = try await folderRoots()
            if opened.count > 1 || opened.first?.path != scan.root {
                if !roots.contains(scan.root) { roots.append(scan.root) }
                let encoded = try JSONEncoder().encode(roots)
                try await registry.setPreference("repository.folderRoots", value: String(decoding: encoded, as: UTF8.self))
            }
        }
        return FolderOpenResult(root: scan.root, repositories: opened, issues: issues)
    }
    public func folderRoots() async throws -> [String] {
        guard let value = try await registry.preference("repository.folderRoots"), let data = value.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }
    public func trust(_ repository: Repository) async throws -> Repository {
        let actual = try await git.discover(path: repository.path)
        guard actual.gitDirectory == repository.gitDirectory, actual.commonDirectory == repository.commonDirectory, actual.identity == repository.identity else {
            throw DeskError("La identidad del repositorio cambió. Vuelve a abrirlo antes de confiar.")
        }
        try Task.checkCancellation()
        var result = repository; result.trusted = true
        try await registry.save(result)
        if result.pendingCheckout {
            await gate.acquire(result.commonDirectory)
            do {
                try await git.materializeClone(result)
                result.pendingCheckout = false
                try await registry.save(result)
                await gate.release(result.commonDirectory)
            } catch { await gate.release(result.commonDirectory); throw error }
        }
        return result
    }
    public func trustAll(ids: [String],
                         progress: (@Sendable (BulkRepositoryProgressEvent) async -> Void)? = nil) async throws -> BulkRepositoryReport {
        let selected = Set(ids)
        let repositories = try await registry.repositories()
            .filter { selected.contains($0.id) }
            .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
        var entries: [BulkRepositoryReport.Entry] = []
        var cancelled = false
        for repository in repositories {
            if Task.isCancelled { cancelled = true; break }
            if let progress { await progress(.started(repository: repository, remote: nil)) }
            if repository.trusted {
                let entry = BulkRepositoryReport.Entry(repository: repository, result: .skipped, detail: "Ya tenía confianza.")
                entries.append(entry)
                if let progress { await progress(.finished(entry)) }
                continue
            }
            if repository.inspectionReason != nil || repository.linkedWorktree {
                let entry = BulkRepositoryReport.Entry(repository: repository, result: .skipped, detail: "Solo admite inspección en este MVP.")
                entries.append(entry)
                if let progress { await progress(.finished(entry)) }
                continue
            }
            do {
                _ = try await trust(repository)
                let entry = BulkRepositoryReport.Entry(repository: repository, result: .completed, detail: "Identidad verificada y confianza guardada.")
                entries.append(entry)
                if let progress { await progress(.finished(entry)) }
            } catch is CancellationError {
                let entry = BulkRepositoryReport.Entry(repository: repository, result: .failed, detail: "Interrumpido; comprueba su estado antes de repetir.")
                entries.append(entry)
                if let progress { await progress(.finished(entry)) }
                cancelled = true
                break
            } catch {
                let entry = BulkRepositoryReport.Entry(repository: repository, result: .failed, detail: error.localizedDescription)
                entries.append(entry)
                if let progress { await progress(.finished(entry)) }
            }
        }
        return BulkRepositoryReport(kind: .trusted, entries: entries, cancelled: cancelled)
    }
    public func fetchAll(profile: ConnectionProfile?,
                         progress: (@Sendable (BulkRepositoryProgressEvent) async -> Void)? = nil) async throws -> BulkRepositoryReport {
        let repositories = try await registry.repositories()
            .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
        var entries: [BulkRepositoryReport.Entry] = []
        var cancelled = false
        repositoryLoop: for repository in repositories {
            if Task.isCancelled { cancelled = true; break }
            if let progress { await progress(.started(repository: repository, remote: nil)) }
            guard repository.trusted else {
                let entry = BulkRepositoryReport.Entry(repository: repository, result: .skipped, detail: "Confianza pendiente.")
                entries.append(entry)
                if let progress { await progress(.finished(entry)) }
                continue
            }
            guard repository.inspectionReason == nil, !repository.linkedWorktree else {
                let entry = BulkRepositoryReport.Entry(repository: repository, result: .skipped, detail: "Solo admite inspección en este MVP.")
                entries.append(entry)
                if let progress { await progress(.finished(entry)) }
                continue
            }
            do {
                let actual = try await git.discover(path: repository.path)
                guard actual.gitDirectory == repository.gitDirectory,
                      actual.commonDirectory == repository.commonDirectory,
                      actual.identity == repository.identity else {
                    let entry = BulkRepositoryReport.Entry(repository: repository, result: .failed, detail: "La identidad cambió. Vuelve a abrirlo antes de hacer fetch.")
                    entries.append(entry)
                    if let progress { await progress(.finished(entry)) }
                    continue
                }
                let remotes = try await git.remotes(repository)
                if remotes.isEmpty {
                    let entry = BulkRepositoryReport.Entry(repository: repository, result: .skipped, detail: "No tiene remotos configurados.")
                    entries.append(entry)
                    if let progress { await progress(.finished(entry)) }
                    continue
                }
                for remote in remotes {
                    if Task.isCancelled { cancelled = true; break repositoryLoop }
                    if let progress { await progress(.started(repository: repository, remote: remote)) }
                    do {
                        _ = try await mutate(.fetch(remote), repository: repository, profile: profile)
                        let entry = BulkRepositoryReport.Entry(repository: repository, remote: remote, result: .completed, detail: "Referencias remotas actualizadas.")
                        entries.append(entry)
                        if let progress { await progress(.finished(entry)) }
                    } catch is CancellationError {
                        let entry = BulkRepositoryReport.Entry(repository: repository, remote: remote, result: .failed, detail: "Fetch interrumpido; consulta las referencias antes de repetir.")
                        entries.append(entry)
                        if let progress { await progress(.finished(entry)) }
                        cancelled = true
                        break repositoryLoop
                    } catch {
                        let entry = BulkRepositoryReport.Entry(repository: repository, remote: remote, result: .failed, detail: error.localizedDescription)
                        entries.append(entry)
                        if let progress { await progress(.finished(entry)) }
                    }
                }
            } catch is CancellationError {
                cancelled = true
                break
            } catch {
                let entry = BulkRepositoryReport.Entry(repository: repository, result: .failed, detail: error.localizedDescription)
                entries.append(entry)
                if let progress { await progress(.finished(entry)) }
            }
        }
        return BulkRepositoryReport(kind: .fetch, entries: entries, cancelled: cancelled)
    }
    public func authorizeTerminal(_ repository: Repository) async throws -> String {
        try await requireTrust(repository)
        let actual = try await git.discover(path: repository.path)
        guard actual.gitDirectory == repository.gitDirectory, actual.commonDirectory == repository.commonDirectory,
              actual.identity == repository.identity, actual.inspectionReason == nil, !actual.linkedWorktree else {
            throw DeskError("El repositorio cambió o solo admite inspección. Vuelve a abrirlo.")
        }
        return actual.path
    }
    public func mutate(_ action: GitAction, repository: Repository,
                       profile: ConnectionProfile?) async throws -> String {
        try await requireTrust(repository)
        await gate.acquire(repository.commonDirectory)
        let operationID = UUID().uuidString
        do {
            try Task.checkCancellation()
            try await registry.record(operation: operationID, phase: "running", repository: repository.path, recovery: nil)
            let result = try await git.execute(action, repository: repository, profile: profile)
            try await registry.record(operation: operationID, phase: "succeeded", repository: repository.path, recovery: nil)
            await gate.release(repository.commonDirectory)
            return result
        } catch {
            try? await registry.record(operation: operationID, phase: "interrupted", repository: repository.path, recovery: nil)
            await gate.release(repository.commonDirectory)
            throw error
        }
    }
    public func clone(source: String, destination: String, profile: ConnectionProfile?) async throws -> Repository {
        await gate.acquire(destination)
        do {
            try Task.checkCancellation()
            let repository = try await git.clone(source: source, destination: destination, profile: profile)
            try await registry.save(repository)
            await gate.release(destination)
            return repository
        } catch { await gate.release(destination); throw error }
    }
    public func prepareAmend(_ repository: Repository, message: String, publish: Bool,
                             remote: String, profile: ConnectionProfile?) async throws -> AmendPlan {
        try await requireTrust(repository)
        let plan = try await git.prepareAmend(repository, message: message, publish: publish, remote: remote, profile: profile)
        plans[plan.id] = plan
        return plan
    }
    public func cancelPlan(_ id: UUID) { plans.removeValue(forKey: id) }
    public func amend(planID: UUID, profile: ConnectionProfile?) async throws -> String {
        guard let plan = plans.removeValue(forKey: planID), Date.now.timeIntervalSince(plan.created) < 60 else {
            throw DeskError("El plan expiró. Vuelve a revisar y confirmar la edición.")
        }
        try await requireTrust(plan.repository)
        await gate.acquire(plan.repository.commonDirectory)
        do {
            try Task.checkCancellation()
            try await registry.record(operation: plan.id.uuidString, phase: "prepared", repository: plan.repository.path, recovery: plan.recoveryReference)
            let result = try await git.executeAmend(plan, profile: profile)
            try await registry.record(operation: plan.id.uuidString, phase: "verified", repository: plan.repository.path, recovery: plan.recoveryReference)
            await gate.release(plan.repository.commonDirectory)
            return result
        } catch {
            try? await registry.record(operation: plan.id.uuidString, phase: "needs-recovery", repository: plan.repository.path, recovery: plan.recoveryReference)
            await gate.release(plan.repository.commonDirectory)
            throw error
        }
    }
    private func requireTrust(_ repository: Repository) async throws {
        let saved = try await registry.repositories().first { $0.id == repository.id }
        guard repository.trusted, saved?.trusted == true, saved?.commonDirectory == repository.commonDirectory, saved?.gitDirectory == repository.gitDirectory, saved?.identity != nil, saved?.identity == repository.identity else {
            throw DeskError("Debes confiar en este repositorio registrado antes de modificarlo.")
        }
        guard repository.inspectionReason == nil else { throw DeskError(repository.inspectionReason!) }
        guard !repository.linkedWorktree else { throw DeskError("Este MVP permite inspeccionar worktrees vinculados, pero no modificarlos.") }
    }
}
