import Foundation

public struct FolderOpenResult: Sendable {
    public let root: String
    public let repositories: [Repository]
    public let issues: [String]
    public init(root: String, repositories: [Repository], issues: [String]) {
        self.root = root; self.repositories = repositories; self.issues = issues
    }
}
