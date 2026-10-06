import Foundation
import Testing
@testable import EfbyGitDeskInfrastructure

struct KeychainTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["EFBY_KEYCHAIN_TEST"] == "1"))
    func isolatedCredentialRoundTripAndRemoval() async throws {
        let vault = KeychainVault()
        let id = "fixture." + UUID().uuidString
        let value = Data("disposable-test-value".utf8)
        do {
            try await vault.save(id: id, value: value)
            #expect(try await vault.load(id: id) == value)
            try await vault.delete(id: id)
        } catch {
            try? await vault.delete(id: id)
            throw error
        }
    }
}
