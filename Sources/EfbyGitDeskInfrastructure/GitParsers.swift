import Foundation
import EfbyGitDeskDomain

public enum GitParsers {
    public static func status(_ data: Data) -> RepositorySnapshot {
        let records = data.split(separator: 0, omittingEmptySubsequences: true)
        var result = RepositorySnapshot()
        var index = 0
        while index < records.count {
            let record = records[index]
            let text = String(decoding: record, as: UTF8.self)
            if text.hasPrefix("# branch.oid ") {
                let value = String(text.dropFirst(13))
                result.head = value == "(initial)" ? "" : value
            } else if text.hasPrefix("# branch.head ") { result.branch = String(text.dropFirst(14)) }
            else if text.hasPrefix("# branch.upstream ") { result.upstream = String(text.dropFirst(18)) }
            else if text.hasPrefix("# branch.ab ") {
                let parts = text.split(separator: " ")
                if parts.count == 4 {
                    result.ahead = Int(parts[2].dropFirst()); result.behind = Int(parts[3].dropFirst())
                }
            } else if record.first == 63 {
                result.files.append(FileChange(path: Data(record.dropFirst(2)), status: "?", unstaged: true))
            } else if let first = record.first, [49, 50, 117].contains(first) {
                let count = first == 50 ? 9 : (first == 117 ? 10 : 8)
                let fields = record.split(separator: 32, maxSplits: count, omittingEmptySubsequences: false)
                if fields.count == count + 1, fields[1].count == 2 {
                    let xy = Array(fields[1])
                    var old: Data?
                    if first == 50, index + 1 < records.count { index += 1; old = Data(records[index]) }
                    result.files.append(FileChange(
                        path: Data(fields[count]), oldPath: old,
                        status: String(decoding: xy, as: UTF8.self),
                        staged: xy[0] != 46, unstaged: xy[1] != 46, conflict: first == 117
                    ))
                }
            }
            index += 1
        }
        return result
    }
    public static func changes(_ data: Data) throws -> [FileChange] {
        let fields = data.split(separator: 0, omittingEmptySubsequences: true)
        var result: [FileChange] = []
        var index = 0
        while index < fields.count {
            let status = String(decoding: fields[index], as: UTF8.self)
            guard index + 1 < fields.count else { throw DeskError("El inventario de cambios está incompleto.") }
            if status.hasPrefix("R") || status.hasPrefix("C") {
                guard index + 2 < fields.count else { throw DeskError("El inventario de cambios está incompleto.") }
                result.append(FileChange(path: Data(fields[index + 2]), oldPath: Data(fields[index + 1]), status: status))
                index += 3
            } else {
                result.append(FileChange(path: Data(fields[index + 1]), status: status))
                index += 2
            }
        }
        return result
    }
    public static func history(_ data: Data) throws -> [Commit] {
        let fields = data.split(separator: 0, omittingEmptySubsequences: false)
        var result: [Commit] = []
        var i = 0
        while i + 5 < fields.count {
            let oid = String(decoding: fields[i], as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            guard ComparisonPair.validOID(oid) else {
                if oid.isEmpty { i += 1; continue }
                throw DeskError("Git devolvió un historial no válido.")
            }
            result.append(Commit(
                oid: oid, parents: String(decoding: fields[i + 1], as: UTF8.self).split(separator: " ").map(String.init),
                message: String(decoding: fields[i + 2], as: UTF8.self), author: String(decoding: fields[i + 3], as: UTF8.self),
                date: String(decoding: fields[i + 4], as: UTF8.self), references: String(decoding: fields[i + 5], as: UTF8.self)
            ))
            i += 6
        }
        return result
    }
}
