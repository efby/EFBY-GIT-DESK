import Foundation
import EfbyGitDeskApplication
import EfbyGitDeskDomain

public struct FolderDiscovery: FolderDiscoveryPort {
    public init() {}
    public func scan(path: String) async throws -> FolderScanResult {
        let task = Task.detached { try Self.walk(path: path) }
        return try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
    }
    private static func walk(path: String) throws -> FolderScanResult {
        let manager = FileManager.default
        let root = URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath()
        let rootPath = root.path
        guard try root.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else {
            throw DeskError("Selecciona una carpeta para buscar repositorios.")
        }
        guard root.lastPathComponent != ".git" else { throw DeskError("Selecciona la carpeta del proyecto, no su directorio .git.") }
        var pending = [root], visited = Set<String>(), found = Set<String>()
        var unreadable = 0, external = 0
        while let next = pending.popLast() {
            // Resource-prefetched URLs can use /private/var while Git and Foundation
            // standardization use /var. Recreate URLs before taking canonical identities.
            let directory = URL(fileURLWithPath: next.path).standardizedFileURL.resolvingSymlinksInPath()
            let directoryPath = directory.path
            try Task.checkCancellation()
            guard visited.insert(directoryPath).inserted else { continue }
            if manager.fileExists(atPath: directory.appendingPathComponent(".git").path) { found.insert(directoryPath) }
            // Report possible bare repositories through Git validation, while continuing to find nested projects.
            if manager.fileExists(atPath: directory.appendingPathComponent("HEAD").path),
               manager.fileExists(atPath: directory.appendingPathComponent("objects").path),
               manager.fileExists(atPath: directory.appendingPathComponent("refs").path),
               manager.fileExists(atPath: directory.appendingPathComponent("config").path) {
                found.insert(directoryPath)
            }
            let children: [URL]
            do { children = try manager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]) }
            catch { unreadable += 1; continue }
            for child in children where child.lastPathComponent != ".git" {
                try Task.checkCancellation()
                do {
                    let values = try child.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                    if values.isSymbolicLink == true {
                        let target = URL(fileURLWithPath: child.path).standardizedFileURL.resolvingSymlinksInPath()
                        let targetPath = target.path
                        guard (try? target.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }
                        guard targetPath == rootPath || targetPath.hasPrefix(rootPath == "/" ? "/" : rootPath + "/") else { external += 1; continue }
                        pending.append(target)
                    } else if values.isDirectory == true { pending.append(child) }
                } catch { unreadable += 1 }
            }
        }
        return FolderScanResult(root: rootPath, paths: found.sorted(), unreadableDirectories: unreadable, externalLinks: external)
    }
}
