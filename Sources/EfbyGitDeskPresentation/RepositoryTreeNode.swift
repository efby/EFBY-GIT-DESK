import Foundation
import EfbyGitDeskDomain

struct RepositoryTreeNode: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    var repository: Repository?
    var children: [RepositoryTreeNode]?
}
