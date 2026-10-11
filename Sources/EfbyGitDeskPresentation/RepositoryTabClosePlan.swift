enum RepositoryTabCloseScope {
    case others
    case left
    case right
}

struct RepositoryTabClosePlan {
    static func targets(in openIDs: [String], relativeTo id: String, scope: RepositoryTabCloseScope) -> [String] {
        guard let index = openIDs.firstIndex(of: id) else { return [] }
        switch scope {
        case .others: return openIDs.filter { $0 != id }
        case .left: return Array(openIDs[..<index])
        case .right: return Array(openIDs[openIDs.index(after: index)...])
        }
    }
}
