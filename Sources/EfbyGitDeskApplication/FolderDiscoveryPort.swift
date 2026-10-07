import Foundation
import EfbyGitDeskDomain

public protocol FolderDiscoveryPort: Sendable {
    func scan(path: String) async throws -> FolderScanResult
}
