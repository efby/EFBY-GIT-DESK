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
        let saved = try await registry.repositories().first(where: { $0.path == result.path })
        if let saved {
            result = Self.mergeRegistration(saved: saved, discovered: result)
        }
        result = Self.applyDefaultTrust(result, prior: saved)
        result.lastOpened = .now
        try await registry.save(result)
        return result
    }

    /// Los proyectos nuevos en el catálogo nacen confiables. Un registro ya guardado como no confiable
    /// o un `.git` sustituido conservan la restricción hasta confiar de nuevo. Los clones sin checkout no.
    static func applyDefaultTrust(_ repository: Repository, prior: Repository?) -> Repository {
        var result = repository
        guard !result.pendingCheckout, prior == nil, !result.trusted else { return result }
        result.trusted = true
        return result
    }

    /// Conserva confianza solo si el directorio Git no cambió. Un catálogo sin identidad
    /// completa se completa sin revocar confianza ya concedida; un `.git` distinto sí la retira.
    static func mergeRegistration(saved: Repository, discovered: Repository) -> Repository {
        var result = discovered
        result.favorite = saved.favorite
        result.group = saved.group
        result.pendingCheckout = saved.pendingCheckout
        let directoriesMatch = saved.gitDirectory == discovered.gitDirectory
            && saved.commonDirectory == discovered.commonDirectory
        guard directoriesMatch else {
            result.trusted = false
            return result
        }
        switch (saved.identity, discovered.identity) {
        case let (savedID?, discoveredID?) where savedID == discoveredID:
            result.trusted = saved.trusted
        case (nil, .some) where saved.trusted:
            result.trusted = true
        case (nil, .some):
            result.trusted = false
        default:
            result.trusted = false
        }
        return result
    }
    public func openFolder(path: String,
                           preservingFolderRoots: [String] = [],
                           progress: (@Sendable (FolderScanProgressEvent) async -> Void)? = nil) async throws -> FolderOpenResult {
        guard let discovery else {
            let repository = try await open(path: path)
            return FolderOpenResult(root: repository.path, repositories: [repository], issues: [])
        }
        let scanProgress: (@Sendable (String, Int, Int) -> Void)?
        if let progress {
            scanProgress = { current, discovered, visited in
                Task { await progress(.scanning(currentPath: current, discovered: discovered, visited: visited)) }
            }
        } else {
            scanProgress = nil
        }
        let scan = try await discovery.scan(path: path, progress: scanProgress)
        var opened: [Repository] = [], issues: [String] = []
        if scan.unreadableDirectories > 0 { issues.append("No se pudieron leer \(scan.unreadableDirectories) carpetas.") }
        if scan.externalLinks > 0 { issues.append("Se omitieron \(scan.externalLinks) enlaces a carpetas fuera de la ubicación elegida.") }
        let candidates = scan.paths
        for (index, candidate) in candidates.enumerated() {
            try Task.checkCancellation()
            let name = URL(fileURLWithPath: candidate).lastPathComponent
            await progress?(.importing(path: candidate, name: name, index: index + 1, total: max(candidates.count, 1)))
            do { opened.append(try await open(path: candidate)) }
            catch is CancellationError { throw CancellationError() }
            catch { issues.append(name + ": " + error.localizedDescription) }
        }
        if candidates.isEmpty {
            // Preserve opening a subfolder within an existing repository.
            do { opened = [try await open(path: path)] }
            catch is CancellationError { throw CancellationError() }
            catch { issues.append("No se encontraron repositorios Git en esta carpeta ni en sus subcarpetas.") }
        }
        if !opened.isEmpty {
            try await persistFolderRoots(scanRoot: scan.root, opened: opened, candidateCount: candidates.count,
                                       ensuring: preservingFolderRoots)
        }
        return FolderOpenResult(root: scan.root, repositories: opened, issues: issues)
    }
    public func folderRoots() async throws -> [String] {
        guard let value = try await registry.preference("repository.folderRoots"), let data = value.data(using: .utf8) else { return [] }
        let decoded = (try? JSONDecoder().decode([String].self, from: data)) ?? []
        return Array(Set(decoded.map(RepositoryFolderPaths.canonical))).sorted()
    }
    public func removeRepositories(under root: String) async throws -> [String] {
        let normalized = RepositoryFolderPaths.canonical(root)
        let removed = try await registry.repositories().filter { RepositoryFolderPaths.contains(normalized, path: $0.path) }
        for repository in removed { try await registry.remove(id: repository.id) }
        return removed.map(\.id)
    }
    /// Quita una carpeta raíz del explorador y todas las referencias a repositorios bajo ella. No borra archivos.
    public func discardFolder(root: String) async throws -> [String] {
        let normalized = RepositoryFolderPaths.canonical(root)
        let removed = try await removeRepositories(under: normalized)
        var roots = try await folderRoots()
        roots.removeAll { RepositoryFolderPaths.contains(normalized, path: $0) }
        let encoded = try JSONEncoder().encode(roots)
        try await registry.setPreference("repository.folderRoots", value: String(decoding: encoded, as: UTF8.self))
        return removed
    }
    /// Actualiza los repositorios bajo una carpeta conservando sus raíces del árbol del explorador.
    public func rescanFolder(root: String,
                            progress: (@Sendable (FolderScanProgressEvent) async -> Void)? = nil) async throws -> FolderOpenResult {
        let normalized = RepositoryFolderPaths.canonical(root)
        let priorRoots = try await folderRoots()
        let preserved = priorRoots.filter {
            RepositoryFolderPaths.canonical($0) == normalized
                || RepositoryFolderPaths.contains(normalized, path: $0)
                || RepositoryFolderPaths.contains($0, path: normalized)
        }
        _ = try await removeRepositories(under: normalized)
        return try await openFolder(path: normalized, preservingFolderRoots: preserved + [normalized], progress: progress)
    }

    private func persistFolderRoots(scanRoot: String, opened: [Repository], candidateCount: Int,
                                    ensuring: [String]) async throws {
        let scanRoot = RepositoryFolderPaths.canonical(scanRoot)
        var roots = Set(try await folderRoots())
        for path in ensuring { roots.insert(RepositoryFolderPaths.canonical(path)) }
        if shouldRegisterFolderRoot(scanRoot: scanRoot, opened: opened, candidateCount: candidateCount) {
            roots.insert(scanRoot)
        }
        let encoded = try JSONEncoder().encode(roots.sorted())
        try await registry.setPreference("repository.folderRoots", value: String(decoding: encoded, as: UTF8.self))
    }

    private func shouldRegisterFolderRoot(scanRoot: String, opened: [Repository], candidateCount: Int) -> Bool {
        guard !opened.isEmpty else { return false }
        if candidateCount > 1 || opened.count > 1 { return true }
        if let only = opened.first, RepositoryFolderPaths.canonical(only.path) != scanRoot { return true }
        return false
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
        return await runBulk(.trusted, repositories: repositories, profile: nil, progress: progress)
    }
    public func fetchAll(profile: ConnectionProfile?,
                         progress: (@Sendable (BulkRepositoryProgressEvent) async -> Void)? = nil) async throws -> BulkRepositoryReport {
        let repositories = try await registry.repositories()
            .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
        return await runBulk(.fetch, repositories: repositories, profile: profile, progress: progress)
    }

    private func runBulk(_ kind: BulkRepositoryReport.Kind, repositories: [Repository], profile: ConnectionProfile?,
                         progress: (@Sendable (BulkRepositoryProgressEvent) async -> Void)?) async -> BulkRepositoryReport {
        // Linked worktrees share a Git directory; never schedule them in separate workers.
        var groups: [[Repository]] = []
        var groupIndex: [String: Int] = [:]
        for repository in repositories {
            if let index = groupIndex[repository.commonDirectory] { groups[index].append(repository) }
            else {
                groupIndex[repository.commonDirectory] = groups.count
                groups.append([repository])
            }
        }
        let batches = groups
        return await withTaskGroup(of: (Int, [BulkRepositoryReport.Entry]).self) { group in
            var next = 0
            var results = Array(repeating: [BulkRepositoryReport.Entry](), count: batches.count)
            for _ in 0..<min(4, batches.count) {
                let index = next; next += 1
                group.addTask { [self] in
                    (index, await processBulkGroup(batches[index], kind: kind, profile: profile, progress: progress))
                }
            }
            while let (index, entries) = await group.next() {
                results[index] = entries
                if Task.isCancelled { group.cancelAll() }
                else if next < batches.count {
                    let index = next; next += 1
                    group.addTask { [self] in
                        (index, await processBulkGroup(batches[index], kind: kind, profile: profile, progress: progress))
                    }
                }
            }
            return BulkRepositoryReport(kind: kind, entries: results.flatMap { $0 }, cancelled: Task.isCancelled)
        }
    }

    private func processBulkGroup(_ repositories: [Repository], kind: BulkRepositoryReport.Kind,
                                  profile: ConnectionProfile?, progress: (@Sendable (BulkRepositoryProgressEvent) async -> Void)?) async -> [BulkRepositoryReport.Entry] {
        var entries: [BulkRepositoryReport.Entry] = []
        for repository in repositories {
            if Task.isCancelled { break }
            if kind == .trusted { entries += await trustOne(repository, progress: progress) }
            else { entries += await fetchOne(repository, profile: profile, progress: progress) }
        }
        return entries
    }

    private func trustOne(_ repository: Repository, progress: (@Sendable (BulkRepositoryProgressEvent) async -> Void)?) async -> [BulkRepositoryReport.Entry] {
        if let progress { await progress(.started(repository: repository, remote: nil)) }
        let entry: BulkRepositoryReport.Entry
        do {
            let refreshed = try await open(path: repository.path)
            if refreshed.inspectionReason != nil || refreshed.linkedWorktree {
                entry = .init(repository: repository, result: .skipped, detail: "Solo admite inspección en este MVP.")
            } else if refreshed.trusted,
                      repository.trusted,
                      refreshed.gitDirectory == repository.gitDirectory,
                      refreshed.commonDirectory == repository.commonDirectory,
                      repository.identity == refreshed.identity {
                entry = .init(repository: repository, result: .skipped, detail: "Ya tenía confianza.")
            } else {
                guard refreshed.gitDirectory == repository.gitDirectory,
                      refreshed.commonDirectory == repository.commonDirectory else {
                    throw DeskError("El registro cambió en disco. Abre el proyecto y confía de nuevo antes de usar acciones globales.")
                }
                if let savedIdentity = repository.identity, savedIdentity != refreshed.identity {
                    throw DeskError("El registro cambió en disco. Abre el proyecto y confía de nuevo antes de usar acciones globales.")
                }
                if refreshed.trusted {
                    entry = .init(repository: repository, result: .skipped, detail: "Ya tenía confianza.")
                } else {
                    _ = try await trust(refreshed)
                    entry = .init(repository: repository, result: .completed, detail: "Identidad verificada y confianza guardada.")
                }
            }
        } catch is CancellationError {
            entry = .init(repository: repository, result: .failed, detail: "Interrumpido; comprueba su estado antes de repetir.")
        } catch {
            entry = .init(repository: repository, result: .failed, detail: error.localizedDescription)
        }
        if let progress { await progress(.finished(entry)) }
        return [entry]
    }

    private func fetchOne(_ repository: Repository, profile: ConnectionProfile?,
                          progress: (@Sendable (BulkRepositoryProgressEvent) async -> Void)?) async -> [BulkRepositoryReport.Entry] {
        if let progress { await progress(.started(repository: repository, remote: nil)) }
        var entries: [BulkRepositoryReport.Entry] = []
        func finish(_ entry: BulkRepositoryReport.Entry) async {
            if let progress { await progress(.finished(entry)) }
        }
        guard repository.trusted else {
            let entry = BulkRepositoryReport.Entry(repository: repository, result: .skipped, detail: "Confianza pendiente.")
            await finish(entry)
            return [entry]
        }
        guard repository.inspectionReason == nil, !repository.linkedWorktree else {
            let entry = BulkRepositoryReport.Entry(repository: repository, result: .skipped, detail: "Solo admite inspección en este MVP.")
            await finish(entry)
            return [entry]
        }
        do {
            let actual = try await git.discover(path: repository.path)
            var working = repository
            if actual.gitDirectory != repository.gitDirectory
                || actual.commonDirectory != repository.commonDirectory
                || actual.identity != repository.identity {
                working = try await open(path: repository.path)
            }
            guard working.trusted else {
                let entry = BulkRepositoryReport.Entry(repository: repository, result: .skipped, detail: "Confianza pendiente tras actualizar el registro.")
                await finish(entry)
                return [entry]
            }
            guard working.gitDirectory == actual.gitDirectory,
                  working.commonDirectory == actual.commonDirectory,
                  working.identity == actual.identity else {
                let entry = BulkRepositoryReport.Entry(repository: repository, result: .failed, detail: "La identidad cambió. Revisa el repositorio antes de hacer fetch.")
                await finish(entry)
                return [entry]
            }
            let remotes = try await git.remotes(working)
            if remotes.isEmpty {
                let entry = BulkRepositoryReport.Entry(repository: repository, result: .skipped, detail: "No tiene remotos configurados.")
                await finish(entry)
                return [entry]
            }
            for remote in remotes {
                if Task.isCancelled { break }
                if let progress { await progress(.started(repository: repository, remote: remote)) }
                let entry: BulkRepositoryReport.Entry
                do {
                    _ = try await mutate(.fetch(remote), repository: working, profile: profile)
                    entry = .init(repository: repository, remote: remote, result: .completed, detail: "Referencias remotas actualizadas.")
                } catch is CancellationError {
                    entry = .init(repository: repository, remote: remote, result: .failed, detail: "Fetch interrumpido; consulta las referencias antes de repetir.")
                } catch {
                    entry = .init(repository: repository, remote: remote, result: .failed, detail: error.localizedDescription)
                }
                entries.append(entry)
                await finish(entry)
            }
        } catch is CancellationError {
            let entry = BulkRepositoryReport.Entry(repository: repository, result: .failed, detail: "Fetch interrumpido; consulta las referencias antes de repetir.")
            entries.append(entry)
            await finish(entry)
        } catch {
            let entry = BulkRepositoryReport.Entry(repository: repository, result: .failed, detail: error.localizedDescription)
            entries.append(entry)
            await finish(entry)
        }
        return entries
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
