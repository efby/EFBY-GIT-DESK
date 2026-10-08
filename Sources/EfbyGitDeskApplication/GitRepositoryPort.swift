import Foundation
import EfbyGitDeskDomain

public protocol GitRepositoryPort: Sendable {
    func executablePath() async throws -> String
    func configureExecutable(path: String?) async throws
    func version() async throws -> String
    func discover(path: String) async throws -> Repository
    func snapshot(_ repository: Repository) async throws -> RepositorySnapshot
    func branches(_ repository: Repository) async throws -> [Branch]
    func history(_ repository: Repository, tips: [String], offset: Int, search: String) async throws -> [Commit]
    func comparisonOrder(_ repository: Repository, tips: [String], selected: [String]) async throws -> [String]
    func changes(_ repository: Repository, context: DiffContext) async throws -> [FileChange]
    func allFiles(_ repository: Repository, context: DiffContext) async throws -> [FileChange]
    func diff(_ repository: Repository, context: DiffContext, file: FileChange) async throws -> String
    func fileComparison(_ repository: Repository, context: DiffContext, file: FileChange) async throws -> FileComparison
    func execute(_ action: GitAction, repository: Repository, profile: ConnectionProfile?) async throws -> String
    func clone(source: String, destination: String, profile: ConnectionProfile?) async throws -> Repository
    func materializeClone(_ repository: Repository) async throws
    func prepareAmend(_ repository: Repository, message: String, publish: Bool, remote: String,
                      profile: ConnectionProfile?) async throws -> AmendPlan
    func executeAmend(_ plan: AmendPlan, profile: ConnectionProfile?) async throws -> String
    func remotes(_ repository: Repository) async throws -> [String]
    func remoteSupported(_ repository: Repository, remote: String) async -> Bool
    func message(_ repository: Repository, oid: String) async throws -> String
}
