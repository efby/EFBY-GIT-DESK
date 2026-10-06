import Foundation

public struct RepositorySnapshot: Sendable {
    public var head: String
    public var branch: String
    public var upstream: String
    public var ahead: Int?
    public var behind: Int?
    public var files: [FileChange]
    public var inspectedAt: Date
    public init(head: String = "", branch: String = "", upstream: String = "",
                ahead: Int? = nil, behind: Int? = nil, files: [FileChange] = [],
                inspectedAt: Date = .now) {
        self.head = head; self.branch = branch; self.upstream = upstream
        self.ahead = ahead; self.behind = behind; self.files = files
        self.inspectedAt = inspectedAt
    }
}
