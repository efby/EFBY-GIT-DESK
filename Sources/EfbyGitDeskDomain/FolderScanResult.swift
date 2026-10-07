import Foundation

public struct FolderScanResult: Sendable {
    public let root: String
    public let paths: [String]
    public let unreadableDirectories: Int
    public let externalLinks: Int
    public init(root: String, paths: [String], unreadableDirectories: Int = 0, externalLinks: Int = 0) {
        self.root = root; self.paths = paths
        self.unreadableDirectories = unreadableDirectories; self.externalLinks = externalLinks
    }
}
