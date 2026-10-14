import Foundation

public enum GitAction: Sendable {
    case stage([Data])
    case unstage([Data])
    case commit(String)
    case createBranch(String)
    case checkout(String)
    case deleteBranch(String)
    case fetch(String)
    case pull(String)
    case push(remote: String, branch: String, setUpstream: Bool)
    case restoreRepositoryState(oid: String, message: String, remote: String, branch: String)
}
