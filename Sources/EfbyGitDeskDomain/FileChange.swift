import Foundation

public struct FileChange: Identifiable, Hashable, Sendable {
    public var id: String { path.base64EncodedString() }
    public let path: Data
    public let oldPath: Data?
    public let status: String
    public let staged: Bool
    public let unstaged: Bool
    public let conflict: Bool
    public var name: String {
        if let value = String(data: path, encoding: .utf8) { return value }
        return path.map { byte in
            (32...126).contains(byte) ? String(UnicodeScalar(byte)) : String(format: "\\x%02x", byte)
        }.joined()
    }
    public var utf8Path: String? { String(data: path, encoding: .utf8) }
    public init(path: Data, oldPath: Data? = nil, status: String,
                staged: Bool = false, unstaged: Bool = false, conflict: Bool = false) {
        self.path = path; self.oldPath = oldPath; self.status = status
        self.staged = staged; self.unstaged = unstaged; self.conflict = conflict
    }
}
