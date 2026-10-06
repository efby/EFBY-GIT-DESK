import Foundation

public struct Branch: Identifiable, Hashable, Sendable {
    public var id: String { reference }
    public let reference: String
    public let oid: String
    public let upstream: String
    public let current: Bool
    public var remote: Bool { reference.hasPrefix("refs/remotes/") }
    public var name: String {
        reference.replacingOccurrences(of: "refs/heads/", with: "")
            .replacingOccurrences(of: "refs/remotes/", with: "")
    }
    public init(reference: String, oid: String, upstream: String, current: Bool) {
        self.reference = reference; self.oid = oid
        self.upstream = upstream; self.current = current
    }
}
