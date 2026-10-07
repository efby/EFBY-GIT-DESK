import Foundation
import Testing
import AppKit
import SwiftUI
import EfbyGitDeskDomain
import EfbyGitDeskApplication
import EfbyGitDeskInfrastructure
@testable import EfbyGitDeskPresentation

struct FolderDiscoveryTests {
    @Test func scansEveryDepthHiddenFoldersPackagesAndNestedRepositoriesWithoutCycles() async throws {
        let f = try await GitFixture.make(); defer { f.cleanup() }
        let workspace = f.folder.appendingPathComponent("workspace")
        let paths = ["division/backend", "division/backend/nested/repo", ".hidden/client", "Bundle.app/Contents/project", "a/b/c/d/e/f/g/deep"]
        for path in paths {
            let directory = workspace.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            _ = try await f.git(["init", "--initial-branch=main", directory.path])
        }
        let nestedGitFile = workspace.appendingPathComponent("worktree")
        try FileManager.default.createDirectory(at: nestedGitFile, withIntermediateDirectories: true)
        try Data("gitdir: ../division/backend/.git\n".utf8).write(to: nestedGitFile.appendingPathComponent(".git"))
        try FileManager.default.createSymbolicLink(at: workspace.appendingPathComponent("alias"), withDestinationURL: workspace.appendingPathComponent("division/backend"))
        try FileManager.default.createSymbolicLink(at: workspace.appendingPathComponent("cycle"), withDestinationURL: workspace)
        try FileManager.default.createSymbolicLink(at: workspace.appendingPathComponent("outside"), withDestinationURL: f.folder)
        let result = try await FolderDiscovery().scan(path: workspace.path)
        #expect(result.paths.count == 6)
        #expect(result.paths.contains(nestedGitFile.resolvingSymlinksInPath().path))
        #expect(result.paths.contains(workspace.appendingPathComponent(paths.last!).resolvingSymlinksInPath().path))
        #expect(result.externalLinks == 1)
        #expect(!result.paths.contains { $0.contains("/.git/") })
        let nestedScan = try await FolderDiscovery().scan(path: workspace.appendingPathComponent("division/backend").path)
        #expect(nestedScan.paths.count == 2)
    }
    @Test func canceledScanStopsAndEmptyFolderHasNoCandidates() async throws {
        let f = try await GitFixture.make(); defer { f.cleanup() }
        let empty = f.folder.appendingPathComponent("empty")
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        #expect(try await FolderDiscovery().scan(path: empty.path).paths.isEmpty)
        let task = Task { try await FolderDiscovery().scan(path: f.folder.path) }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
    }
    @MainActor @Test func importsProjectsPreservesTrustAndPersistsTreeRootsAcrossReload() async throws {
        let f = try await GitFixture.make(); defer { f.cleanup() }
        let workspace = f.folder.appendingPathComponent("workspace")
        for path in ["Services/api", "Services/ui", "Personal/project"] {
            let directory = workspace.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            _ = try await f.git(["init", "--initial-branch=main", directory.path])
        }
        let registry = try SQLiteRegistry(path: f.folder.appendingPathComponent("catalog.sqlite").path)
        let service = DeskService(git: f.adapter, registry: registry, cloud: BitbucketClient(vault: KeychainVault()), discovery: FolderDiscovery())
        let first = try await service.open(path: workspace.appendingPathComponent("Services/api").path)
        var trusted = try await service.trust(first); trusted.favorite = true; trusted.group = "Equipo"
        try await registry.save(trusted)
        let imported = try await service.openFolder(path: workspace.path)
        #expect(imported.repositories.count == 3)
        #expect(imported.repositories.filter(\.trusted).count == 1)
        #expect(imported.repositories.first { $0.path == first.path }?.favorite == true)
        #expect(imported.issues.isEmpty)
        let reopened = DeskService(git: f.adapter, registry: registry, cloud: BitbucketClient(vault: KeychainVault()), discovery: FolderDiscovery())
        #expect(try await reopened.folderRoots() == [workspace.resolvingSymlinksInPath().path])
        _ = try await reopened.openFolder(path: workspace.path)
        #expect(try await registry.repositories().count == 3)
        let model = DeskModel(service: reopened, terminalFactory: { PTYTerminal(shell: "/bin/sh", login: false) })
        model.repositories = try await registry.repositories(); model.folderRoots = try await reopened.folderRoots()
        model.sidebarSelection = workspace.path
        #expect(model.selectedID == nil) // Clicking a grouping folder cannot activate it as a repository.
        model.sidebarSelection = first.id
        #expect(model.selectedID == first.id)
        if let path = ProcessInfo.processInfo.environment["EFBY_PROJECT_TREE_PREVIEW_PATH"] {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 650), styleMask: .borderless, backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false; defer { window.close() }
            window.appearance = NSAppearance(named: .darkAqua)
            model.repositorySearch = ""
            let hosting = NSHostingView(rootView: RepositorySidebar(model: model).preferredColorScheme(.dark).background(Color(nsColor: .windowBackgroundColor)))
            hosting.appearance = window.appearance; hosting.sizingOptions = []; window.contentView = hosting
            hosting.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(200)); hosting.layoutSubtreeIfNeeded(); hosting.displayIfNeeded()
            let bitmap = try #require(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
            hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
            try #require(bitmap.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: path))
            model.repositorySearch = "Personal/project"
            try await Task.sleep(for: .milliseconds(100)); hosting.layoutSubtreeIfNeeded(); hosting.displayIfNeeded()
            let searchBitmap = try #require(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
            hosting.cacheDisplay(in: hosting.bounds, to: searchBitmap)
            try #require(searchBitmap.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: path + "-search.png"))
        }
    }
    @Test func invalidGitMarkerDoesNotPreventImportingOtherProjects() async throws {
        let f = try await GitFixture.make(); defer { f.cleanup() }
        let root = f.folder.appendingPathComponent("projects")
        let valid = root.appendingPathComponent("valid"), invalid = root.appendingPathComponent("invalid")
        for directory in [valid, invalid] { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
        _ = try await f.git(["init", "--initial-branch=main", valid.path])
        try Data("invalid".utf8).write(to: invalid.appendingPathComponent(".git"))
        let registry = try SQLiteRegistry(path: f.folder.appendingPathComponent("catalog.sqlite").path)
        let service = DeskService(git: f.adapter, registry: registry, cloud: BitbucketClient(vault: KeychainVault()), discovery: FolderDiscovery())
        let result = try await service.openFolder(path: root.path)
        #expect(result.repositories.count == 1)
        #expect(result.repositories[0].path == valid.resolvingSymlinksInPath().path)
        #expect(!result.repositories[0].trusted)
        #expect(result.issues.count == 1)
    }
    @Test func discoversRealLinkedWorktreesAndReportsUnsupportedBareRepositories() async throws {
        let f = try await GitFixture.make(); defer { f.cleanup() }
        let root = f.folder.appendingPathComponent("workspaces")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let worktree = root.appendingPathComponent("linked")
        _ = try await f.git(["worktree", "add", "--detach", worktree.path, "HEAD"])
        _ = try await f.git(["init", "--bare", root.appendingPathComponent("archive.git").path])
        let registry = try SQLiteRegistry(path: f.folder.appendingPathComponent("catalog.sqlite").path)
        let service = DeskService(git: f.adapter, registry: registry, cloud: BitbucketClient(vault: KeychainVault()), discovery: FolderDiscovery())
        let result = try await service.openFolder(path: root.path)
        #expect(result.repositories.count == 1)
        #expect(result.repositories.first?.linkedWorktree == true)
        #expect(result.repositories.first?.trusted == false)
        #expect(result.issues.contains { $0.contains("bare") })
    }
    @Test func directoryTreeKeepsHierarchyAndMergesOverlappingRoots() {
        func repo(_ path: String) -> Repository { Repository(path: path, gitDirectory: path + "/.git", commonDirectory: path + "/.git", name: URL(fileURLWithPath: path).lastPathComponent) }
        let repositories = [repo("/Projects/team/api"), repo("/Projects/team/ui"), repo("/Projects/team/api/nested"), repo("/ProjectSibling/repo")]
        let tree = RepositoryTreeBuilder.make(repositories: repositories, roots: ["/Projects", "/Projects/team"])
        #expect(tree.count == 2)
        let root = tree.first { $0.id == "/Projects" }
        #expect(root?.children?.count == 1)
        let team = root?.children?.first
        #expect(team?.children?.count == 2)
        #expect(team?.children?.first?.repository?.name == "api")
        #expect(team?.children?.first?.children?.first?.repository?.name == "nested")
        #expect(tree.first { $0.id == "/ProjectSibling/repo" }?.repository != nil)
    }
}
