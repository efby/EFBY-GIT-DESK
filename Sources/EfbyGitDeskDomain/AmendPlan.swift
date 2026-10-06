import Foundation

public struct AmendPlan: Identifiable, Sendable {
    public let id: UUID
    public let repository: Repository
    public let oldHead: String
    public let tree: String
    public let parents: String
    public let author: String
    public let branch: String
    public let oldMessage: String
    public let newMessage: String
    public let destination: String?
    public let expectedRemote: String?
    public let created: Date
    public var recoveryReference: String { "refs/efbygitdesk/backups/" + id.uuidString.lowercased() }
    public init(repository: Repository, oldHead: String, tree: String, parents: String,
                author: String, branch: String, oldMessage: String, newMessage: String,
                destination: String?, expectedRemote: String?, created: Date = .now) {
        self.id = UUID(); self.repository = repository; self.oldHead = oldHead
        self.tree = tree; self.parents = parents; self.author = author; self.branch = branch
        self.oldMessage = oldMessage; self.newMessage = newMessage
        self.destination = destination; self.expectedRemote = expectedRemote; self.created = created
    }
}
