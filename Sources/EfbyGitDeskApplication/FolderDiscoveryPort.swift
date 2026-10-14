import Foundation
import EfbyGitDeskDomain

public protocol FolderDiscoveryPort: Sendable {
    func scan(path: String,
              progress: (@Sendable (String, Int, Int) -> Void)?) async throws -> FolderScanResult
}
