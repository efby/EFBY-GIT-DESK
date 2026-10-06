import Foundation
import EfbyGitDeskDomain

public actor DeskService {
    public let git: any GitRepositoryPort
    public let registry: any RegistryPort
    public let cloud: any HostingProviderPort
    private let gate = OperationGate()
    private var plans: [UUID: AmendPlan] = [:]
    public init(git: any GitRepositoryPort, registry: any RegistryPort, cloud: any HostingProviderPort) {
        self.git = git; self.registry = registry; self.cloud = cloud
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
    public func trust(_ repository: Repository) async throws -> Repository {
        let actual = try await git.discover(path: repository.path)
        guard actual.gitDirectory == repository.gitDirectory, actual.commonDirectory == repository.commonDirectory, actual.identity == repository.identity else {
            throw DeskError("La identidad del repositorio cambió. Vuelve a abrirlo antes de confiar.")
        }
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
