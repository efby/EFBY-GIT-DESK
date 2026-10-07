import Foundation
import EfbyGitDeskDomain

struct ComparisonFileNode: Identifiable {
    let id: String
    let name: String
    let file: FileChange?
    let children: [ComparisonFileNode]
    var count: Int { file == nil ? children.reduce(0) { $0 + $1.count } : 1 }

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
                ComparisonFileNode(id: "file:" + $0.id, name: name, file: $0, children: [])
            }
            let nested = members.filter { $0.path != path }
            if !nested.isEmpty {
                nodes.append(ComparisonFileNode(id: "folder:" + path.base64EncodedString(), name: name,
                    file: nil, children: make(nested, prefix: path + Data([47]))))
            }
            return nodes
        }
    }
}
