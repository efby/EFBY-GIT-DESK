import Foundation
import EfbyGitDeskDomain

struct RepositoryTreeBuilder {
    static func contains(_ root: String, path: String) -> Bool { path == root || path.hasPrefix(root == "/" ? "/" : root + "/") }
    static func make(repositories: [Repository], roots: [String]) -> [RepositoryTreeNode] {
        let candidates = Array(Set(roots)).sorted { $0.count < $1.count }
        var outer: [String] = []
        for root in candidates where !outer.contains(where: { contains($0, path: root) }) { outer.append(root) }
        var result: [RepositoryTreeNode] = []
        for root in outer {
            let members = repositories.filter { contains(root, path: $0.path) }
            guard !members.isEmpty else { continue }
            let node = branch(path: root, repositories: members)
            result.append(node)
        }
        for repository in repositories where !outer.contains(where: { contains($0, path: repository.path) }) {
            result.append(RepositoryTreeNode(id: repository.id, name: repository.name, repository: repository))
        }
        return result.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    private static func branch(path: String, repositories: [Repository]) -> RepositoryTreeNode {
        let repository = repositories.first { $0.path == path }
        let descendants = repositories.filter { $0.path != path }
        let groups = Dictionary(grouping: descendants) { repository in
            String(repository.path.dropFirst(path == "/" ? 1 : path.count + 1).split(separator: "/", maxSplits: 1)[0])
        }
        let children = groups.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }.map { name in
            branch(path: URL(fileURLWithPath: path).appendingPathComponent(name).path, repositories: groups[name]!)
        }
        return RepositoryTreeNode(id: path, name: URL(fileURLWithPath: path).lastPathComponent,
                                  repository: repository, children: children.isEmpty ? nil : children)
    }

}
