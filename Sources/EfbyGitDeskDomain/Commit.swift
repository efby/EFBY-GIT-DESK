import Foundation

public struct Commit: Identifiable, Hashable, Sendable {
    public var id: String { oid }
    public let oid: String
    public let parents: [String]
    public let message: String
    public let author: String
    public let date: String
    public let references: String
    public var shortOID: String { String(oid.prefix(8)) }

    public init(oid: String, parents: [String], message: String,
                author: String, date: String, references: String) {
        self.oid = oid; self.parents = parents; self.message = message
        self.author = author; self.date = date; self.references = references
    }
}
