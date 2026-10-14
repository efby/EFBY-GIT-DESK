import Foundation

public enum FolderScanProgressEvent: Sendable {
    case scanning(currentPath: String, discovered: Int, visited: Int)
    case importing(path: String, name: String, index: Int, total: Int)
}

public struct FolderScanEntry: Identifiable, Sendable, Equatable {
    public enum Result: String, Sendable { case completed, failed }
    public let id = UUID()
    public let path: String
    public let name: String
    public let detail: String
    public let result: Result
    public init(path: String, name: String, detail: String, result: Result) {
        self.path = path; self.name = name; self.detail = detail; self.result = result
    }
}
