import Foundation
import AppKit
import SwiftUI
import Testing
import EfbyGitDeskDomain
import EfbyGitDeskApplication
import EfbyGitDeskInfrastructure
@testable import EfbyGitDeskPresentation

@MainActor struct DiffSelectionTests {
    @Test func allFilesModeIncludesUnchangedCodeAndPreservesDeletedChanges() async throws {
        let fixture = try await GitFixture.make(); defer { fixture.cleanup() }
        try FileManager.default.createDirectory(at: fixture.folder.appendingPathComponent("src"), withIntermediateDirectories: true)
        try fixture.write("src/unchanged.py", "print('same')\n")
        _ = try await fixture.git(["add", "--", "src/unchanged.py"])
        _ = try await fixture.git(["commit", "-m", "Add source"])
        let base = try await fixture.git(["rev-parse", "HEAD"])
        _ = try await fixture.git(["rm", "--", "README.md"])
        try fixture.write("src/new.py", "print('new')\n")
        _ = try await fixture.git(["add", "--", "src/new.py"])
        _ = try await fixture.git(["commit", "-m", "Replace file"])
        let target = try await fixture.git(["rev-parse", "HEAD"])
        let pair = try ComparisonPair(base: base, target: target)
        let listed = try await fixture.adapter.allFiles(fixture.repository, context: .commits(pair))
        #expect(Set(listed.map(\.name)) == ["src/unchanged.py", "src/new.py"])

        let registry = try SQLiteRegistry(path: fixture.folder.appendingPathComponent("catalog.sqlite").path)
        let service = DeskService(git: fixture.adapter, registry: registry, cloud: BitbucketClient(vault: KeychainVault()))
        let repository = try await service.open(path: fixture.folder.path)
        let model = DeskModel(service: service, terminalFactory: { PTYTerminal(shell: "/bin/sh", login: false) })
        model.repositories = [repository]; model.select(repository.id)
        try await waitUntil { !model.loading && model.commits.count == 3 }
        model.chooseCommit(model.commits[0]); model.chooseCommit(model.commits[1])
        try await waitUntil { !model.filesLoading && model.files.count == 2 }
        #expect(Set(model.visibleFiles.map(\.name)) == ["README.md", "src/new.py"])

        model.setShowAllFiles(true)
        try await waitUntil { !model.filesLoading && model.visibleFiles.count == 3 }
        #expect(Set(model.visibleFiles.map(\.name)) == ["README.md", "src/new.py", "src/unchanged.py"])
        let unchanged = try #require(model.visibleFiles.first { $0.name == "src/unchanged.py" })
        #expect(unchanged.status == "=")
        model.loadDiff(id: unchanged.id)
        try await waitUntil { !model.diffLoading && model.comparison != nil }
        #expect(model.comparison?.before == "print('same')\n")
        #expect(model.comparison?.after == "print('same')\n")
        #expect(model.diffBlocks.isEmpty)
        model.setShowAllFiles(false)
        try await waitUntil { !model.filesLoading && model.visibleFiles.count == 2 }
        #expect(model.selectedFile == unchanged.id)
        #expect(model.comparison?.after == "print('same')\n")
    }

    @Test func functionLinksOpenTheirFileAndJumpToTheMatchingLine() async throws {
        let fixture = try await GitFixture.make(); defer { fixture.cleanup() }
        try FileManager.default.createDirectory(at: fixture.folder.appendingPathComponent("src"), withIntermediateDirectories: true)
        try fixture.write("src/dynamodb.py", "def query_objects(table):\n    return worker.run(\n")
        try fixture.write("src/worker.py", "def run():\n    return 1\n")
        try fixture.write("src/caller.py", "def main():\n    dynamodb.query_objects(\n    run(\n")
        _ = try await fixture.git(["add", "--", "src/dynamodb.py", "src/worker.py", "src/caller.py"])
        _ = try await fixture.git(["commit", "-m", "Add code"])
        _ = try await fixture.commit("README.md", "updated\n", message: "Update readme")
        let registry = try SQLiteRegistry(path: fixture.folder.appendingPathComponent("symbols.sqlite").path)
        let service = DeskService(git: fixture.adapter, registry: registry, cloud: BitbucketClient(vault: KeychainVault()))
        let repository = try await service.open(path: fixture.folder.path)
        let model = DeskModel(service: service, terminalFactory: { PTYTerminal(shell: "/bin/sh", login: false) })
        model.repositories = [repository]; model.select(repository.id)
        try await waitUntil { !model.loading && model.commits.count == 3 }
        model.chooseCommit(model.commits[0]); model.chooseCommit(model.commits[1])
        try await waitUntil { !model.filesLoading && model.files.count == 1 }
        model.setShowAllFiles(true)
        try await waitUntil { !model.filesLoading && model.visibleFiles.contains { $0.name == "src/caller.py" } }
        let caller = try #require(model.visibleFiles.first { $0.name == "src/caller.py" })
        model.loadDiff(id: caller.id)
        try await waitUntil { !model.diffLoading && model.callLinks?.after.contains { $0.contains { $0.name == "query_objects" } } == true }
        let query = try #require(model.callLinks?.after.flatMap { $0 }.first { $0.name == "query_objects" })
        let run = try #require(model.callLinks?.after.flatMap { $0 }.first { $0.name == "run" })
        #expect(query.path == "src/dynamodb.py")
        #expect(run.path == "src/worker.py")
        model.followDeclaration(fileID: query.fileID, line: query.line, before: query.before, name: query.name, callLine: query.callLine)
        #expect(model.linkTrail.map(\.fileID) == [caller.id])
        try await waitUntil { model.selectedFile == query.fileID && !model.diffLoading && model.symbolJump != nil }
        let jump = try #require(model.symbolJump)
        #expect(model.diffRows[jump.row].afterNumber == query.line)
        #expect(model.declarations.contains { $0.name == "query_objects" && $0.path == "src/dynamodb.py" })
        try await waitUntil { model.callLinks?.after.contains { $0.contains { $0.name == "run" && $0.path == "src/worker.py" } } == true }
        let worker = try #require(model.callLinks?.after.flatMap { $0 }.first { $0.name == "run" && $0.path == "src/worker.py" })
        model.followDeclaration(fileID: worker.fileID, line: worker.line, before: worker.before, name: worker.name, callLine: worker.callLine)
        #expect(model.linkTrail.map(\.fileID) == [caller.id, query.fileID])
        model.returnAlongLink()
        try await waitUntil { model.selectedFile == query.fileID && !model.diffLoading }
        model.returnAlongLink()
        try await waitUntil { model.selectedFile == caller.id && !model.diffLoading && model.linkTrail.isEmpty }
        model.setShowAllFiles(false)
        try await waitUntil { !model.filesLoading && model.callLinks == nil && model.selectedFile == caller.id && model.comparison != nil }
        if let path = ProcessInfo.processInfo.environment["EFBY_SYMBOL_NAV_PREVIEW_PATH"] {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1440, height: 800),
                                  styleMask: .borderless, backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false; defer { window.close() }
            window.appearance = NSAppearance(named: .darkAqua)
            let hosting = NSHostingView(rootView: ComparisonWorkspaceLayer(model: model) { WorkspaceRetentionProbe(view: NSView()) })
            hosting.appearance = window.appearance; hosting.sizingOptions = []; window.contentView = hosting
            hosting.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(200))
            hosting.layoutSubtreeIfNeeded(); hosting.displayIfNeeded()
            let bitmap = try #require(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
            hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
            try #require(bitmap.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: path))
        }
    }

    @Test func diffRequiresFileSelectionAndStaysClosedAfterRefresh() async throws {
        let fixture = try await GitFixture.make()
        defer { fixture.cleanup() }
        _ = try await fixture.commit("README.md", "changed\n", message: "Change file")
        let registry = try SQLiteRegistry(path: fixture.folder.appendingPathComponent("catalog.sqlite").path)
        let service = DeskService(git: fixture.adapter, registry: registry, cloud: BitbucketClient(vault: KeychainVault()))
        let repository = try await service.open(path: fixture.folder.path)
        let model = DeskModel(service: service, terminalFactory: { PTYTerminal(shell: "/bin/sh", login: false) })
        model.repositories = [repository]
        model.select(repository.id)
        try await waitUntil { !model.loading && model.commits.count == 2 }
        model.chooseCommit(model.commits[0])
        try await waitUntil { !model.filesLoading && model.files.count == 1 }
        #expect(model.selectedFile == nil)
        #expect(model.diffText.isEmpty)

        let file = try #require(model.files.first)
        model.loadDiff(id: file.id)
        try await waitUntil { model.diffText.contains("+changed") }
        #expect(model.selectedFile == file.id)
        model.loadDiff(id: file.id)
        #expect(model.comparison != nil)
        #expect(!model.diffLoading) // Refresh must keep the native columns mounted.
        model.refresh()
        try await waitUntil { !model.loading && !model.filesLoading && model.diffText.contains("+changed") }
        #expect(model.selectedFile == file.id)

        model.closeDiff()
        model.refresh()
        try await waitUntil { !model.loading && !model.filesLoading }
        #expect(model.selectedFile == nil)
        #expect(model.diffText.isEmpty)

        model.loadDiff(id: file.id)
        try await waitUntil { model.diffText.contains("+changed") }
        model.chooseCommit(model.commits[1])
        #expect(model.selectedFile == nil)
        try await waitUntil { !model.filesLoading && !model.files.isEmpty }
        #expect(model.selectedFile == nil)
        #expect(model.diffText.isEmpty)
        model.chooseCommit(model.commits[0])
        model.chooseCommit(model.commits[1])
        #expect(model.context == nil)
        #expect(model.selectedFile == nil)
        #expect(model.files.isEmpty)
        #expect(!model.filesLoading)
    }

    @Test func overlayKeepsFileNavigatorWhileSwitchingComparedFiles() async throws {
        let fixture = try await GitFixture.make(); defer { fixture.cleanup() }
        try fixture.write("README.md", "changed readme\n")
        try fixture.write("script.py", "print('new')\n")
        _ = try await fixture.git(["add", "--", "README.md", "script.py"])
        _ = try await fixture.git(["commit", "-m", "Two files"])
        let registry = try SQLiteRegistry(path: fixture.folder.appendingPathComponent("catalog.sqlite").path)
        let service = DeskService(git: fixture.adapter, registry: registry, cloud: BitbucketClient(vault: KeychainVault()))
        let repository = try await service.open(path: fixture.folder.path)
        let model = DeskModel(service: service, terminalFactory: { PTYTerminal(shell: "/bin/sh", login: false) })
        model.repositories = [repository]; model.select(repository.id)
        try await waitUntil { !model.loading && model.commits.count == 2 }
        model.chooseCommit(model.commits[0]); model.chooseCommit(model.commits[1])
        try await waitUntil { !model.filesLoading && model.files.count == 2 }
        let context = model.context, pair = model.orderedComparison
        let readme = try #require(model.files.first { $0.name == "README.md" })
        let script = try #require(model.files.first { $0.name == "script.py" })
        model.loadDiff(id: readme.id)
        try await waitUntil { !model.diffLoading && model.comparison != nil }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1280, height: 800), styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; defer { window.close() }
        window.appearance = NSAppearance(named: .darkAqua)
        let probe = NSView()
        let hosting = NSHostingView(rootView: ComparisonWorkspaceLayer(model: model) { WorkspaceRetentionProbe(view: probe) })
        hosting.appearance = window.appearance; hosting.sizingOptions = []; window.contentView = hosting
        func splits(_ view: NSView) -> [PersistentSplitContainer] {
            ((view as? PersistentSplitContainer).map { [$0] } ?? []) + view.subviews.flatMap { splits($0) }
        }
        try await waitUntil {
            hosting.layoutSubtreeIfNeeded()
            guard let split = splits(hosting).first, split.arrangedSubviews.count > 1 else { return false }
            return abs(split.arrangedSubviews[1].frame.width - 340) < 1
        }
        let split = try #require(splits(hosting).first)
        let navigator = split.arrangedSubviews[1]
        #expect(abs(navigator.frame.width - 340) < 1)
        #expect(navigator.frame.minX > split.arrangedSubviews[0].frame.minX)
        #expect(navigator.window === window)
        model.loadDiff(id: script.id)
        #expect(model.selectedFile == script.id)
        #expect(model.diffLoading)
        try await waitUntil { !model.diffLoading && model.comparison?.after?.contains("print('new')") == true }
        try await waitUntil {
            hosting.layoutSubtreeIfNeeded()
            return splits(hosting).first === split && split.arrangedSubviews[1] === navigator
        }
        #expect(splits(hosting).first === split)
        #expect(split.arrangedSubviews[1] === navigator)
        #expect(probe.window === window)
        #expect(model.context == context && model.orderedComparison == pair)
        #expect(model.files.count == 2)
        if let path = ProcessInfo.processInfo.environment["EFBY_FILE_NAVIGATOR_PREVIEW_PATH"] {
            hosting.displayIfNeeded()
            let bitmap = try #require(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
            hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
            try #require(bitmap.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: path))
        }
        model.closeDiff()
        #expect(model.selectedFile == nil && model.files.count == 2)
        #expect(model.context == context && model.orderedComparison == pair)
    }

    @Test func workspaceTabsKeepStagedAndUnstagedInventoriesSeparate() async throws {
        let fixture = try await GitFixture.make(); defer { fixture.cleanup() }
        let catalog = FileManager.default.temporaryDirectory.appendingPathComponent("GitDeskTabsCatalog-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: catalog, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: catalog) }
        let registry = try SQLiteRegistry(path: catalog.appendingPathComponent("catalog.sqlite").path)
        let service = DeskService(git: fixture.adapter, registry: registry, cloud: BitbucketClient(vault: KeychainVault()))
        let opened = try await service.open(path: fixture.folder.path)
        let model = DeskModel(service: service, terminalFactory: { PTYTerminal(shell: "/bin/sh", login: false) })
        model.repositories = [opened]; model.select(opened.id)
        try await waitUntil { !model.loading && !model.commits.isEmpty }
        model.workspaceSection = .pending
        #expect(model.workspaceSection == .history) // Trust is required, even for programmatic tab changes.
        let repository = try await service.trust(opened)
        model.repositories = [repository]
        try fixture.write("README.md", "staged content\n")
        _ = try await fixture.git(["add", "--", "README.md"])
        try fixture.write("pending.txt", "pending content\n")
        model.snapshot = try await fixture.adapter.snapshot(repository)
        model.workspaceSection = .staged
        try await waitUntil { !model.filesLoading && model.files.count == 1 }
        #expect(model.context == .staged)
        #expect(model.files.first?.name == "README.md")
        model.loadDiff(id: try #require(model.files.first?.id))
        try await waitUntil { model.comparison != nil }
        model.workspaceSection = .pending
        #expect(model.selectedFile == nil)
        try await waitUntil { !model.filesLoading && model.files.contains { $0.name == "pending.txt" } }
        #expect(model.context == .working)
        #expect(!model.files.contains { $0.name == "README.md" })
        if let path = ProcessInfo.processInfo.environment["EFBY_TABS_PREVIEW_PATH"] {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 700), styleMask: .borderless, backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false; defer { window.close() }
            let hosting = NSHostingView(rootView: RepositoryWorkArea(model: model).preferredColorScheme(.dark).tint(.teal))
            window.appearance = NSAppearance(named: .darkAqua)
            hosting.appearance = NSAppearance(named: .darkAqua)
            hosting.sizingOptions = []; window.contentView = hosting
            hosting.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(200)); hosting.layoutSubtreeIfNeeded(); hosting.displayIfNeeded()
            let bitmap = try #require(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
            hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
            try #require(bitmap.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: path))
        }
        #expect(model.selectedOIDs.isEmpty)
        model.workspaceSection = .history
        #expect(model.context == nil)
        #expect(model.files.isEmpty)
        #expect(model.selectedID == repository.id)
        #expect(!model.loading)
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(20))
        while !condition() {
            guard ContinuousClock.now < deadline else { throw CocoaError(.fileReadUnknown) }
            try await Task.sleep(for: .milliseconds(20))
        }
    }
}
