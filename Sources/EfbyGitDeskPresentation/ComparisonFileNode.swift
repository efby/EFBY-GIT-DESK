import Foundation
import EfbyGitDeskDomain

struct ComparisonFileNode: Identifiable, Sendable {
    let id: String
    let name: String
    let file: FileChange?
    let children: [ComparisonFileNode]
    let count: Int
    let folderIDs: Set<String>

    static func make(_ files: [FileChange], prefix: Data = Data()) -> [ComparisonFileNode] {
        var keys: [Data] = []
        var groups: [Data: [FileChange]] = [:]
        for file in files {
            let remaining = file.path.dropFirst(prefix.count)
            let part = Data(remaining.prefix { $0 != 47 })
            if groups[part] == nil { keys.append(part) }
            groups[part, default: []].append(file)
        }
        return keys.flatMap { part -> [ComparisonFileNode] in
            let path = prefix + part
            let members = groups[part] ?? []
            let name = FileChange(path: part, status: "").name
            var nodes = members.filter { $0.path == path }.map {
                ComparisonFileNode(id: "file:" + $0.id, name: name, file: $0, children: [], count: 1, folderIDs: [])
            }
            let nested = members.filter { $0.path != path }
            if !nested.isEmpty {
                let children = make(nested, prefix: path + Data([47]))
                let folderID = "folder:" + path.base64EncodedString()
                let count = children.reduce(0) { $0 + $1.count }
                let folders = children.reduce(into: Set([folderID])) { $0.formUnion($1.folderIDs) }
                nodes.append(ComparisonFileNode(id: folderID, name: name, file: nil, children: children, count: count, folderIDs: folders))
            }
            return nodes
        }
    }
}
