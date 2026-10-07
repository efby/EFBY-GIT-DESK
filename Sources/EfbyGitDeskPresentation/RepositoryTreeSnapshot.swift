import Foundation
import EfbyGitDeskDomain

struct RepositoryTreeSnapshot: Equatable, Sendable {
    let repositories: [Repository]
    let roots: [String]
}
