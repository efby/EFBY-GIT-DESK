import Foundation
import EfbyGitDeskDomain

public protocol RegistryPort: Sendable {
    func repositories() async throws -> [Repository]
    func save(_ repository: Repository) async throws
    func remove(id: String) async throws
    func profiles() async throws -> [ConnectionProfile]
    func saveProfile(_ profile: ConnectionProfile) async throws
    func removeProfile(id: String) async throws
    func preference(_ key: String) async throws -> String?
    func setPreference(_ key: String, value: String) async throws
    func record(operation: String, phase: String, repository: String, recovery: String?) async throws
}
