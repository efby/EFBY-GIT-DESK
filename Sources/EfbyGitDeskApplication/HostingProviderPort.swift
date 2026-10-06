import Foundation
import EfbyGitDeskDomain

public protocol HostingProviderPort: Sendable {
    func saveToken(email: String, token: String) async throws -> ConnectionProfile
    func removeToken(profile: ConnectionProfile) async throws
    func repositories(profile: ConnectionProfile) async throws -> [CloudRepository]
}
