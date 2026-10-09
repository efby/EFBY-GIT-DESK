import Foundation
import EfbyGitDeskDomain

public struct BulkRepositoryReport: Identifiable, Sendable {
    public enum Kind: String, Sendable {
        case trusted = "Confianza"
        case fetch = "Fetch"
    }

    public struct Entry: Identifiable, Sendable {
        public enum Result: Sendable, Equatable { case completed, skipped, failed }

        public let id = UUID()
        public let name: String
        public let path: String
        public let remote: String?
        public let result: Result
        public let detail: String

        public init(repository: Repository, remote: String? = nil, result: Result, detail: String) {
            name = repository.name
            path = repository.path
            self.remote = remote
            self.result = result
            self.detail = detail
        }
    }

    public let id = UUID()
    public let kind: Kind
    public let entries: [Entry]
    public let cancelled: Bool

    public init(kind: Kind, entries: [Entry], cancelled: Bool = false) {
        self.kind = kind
        self.entries = entries
        self.cancelled = cancelled
    }

    public var completed: Int { entries.filter { $0.result == .completed }.count }
    public var skipped: Int { entries.filter { $0.result == .skipped }.count }
    public var failed: Int { entries.filter { $0.result == .failed }.count }
}

public enum BulkRepositoryProgressEvent: Sendable {
    case started(repository: Repository, remote: String?)
    case finished(BulkRepositoryReport.Entry)
}
