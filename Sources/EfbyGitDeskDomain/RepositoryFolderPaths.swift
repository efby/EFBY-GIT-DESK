import Foundation

public enum RepositoryFolderPaths {
    public static func canonical(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path
    }
    public static func contains(_ root: String, path: String) -> Bool {
        let root = canonical(root)
        let path = canonical(path)
        return path == root || path.hasPrefix(root == "/" ? root + "/" : root + "/")
    }
}
