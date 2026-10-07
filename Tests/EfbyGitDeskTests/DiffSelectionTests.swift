import Foundation
import AppKit
import SwiftUI
import Testing
import EfbyGitDeskDomain
import EfbyGitDeskApplication
import EfbyGitDeskInfrastructure
@testable import EfbyGitDeskPresentation

@MainActor struct DiffSelectionTests {
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
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while !condition() {
            guard ContinuousClock.now < deadline else { throw CocoaError(.fileReadUnknown) }
            try await Task.sleep(for: .milliseconds(20))
        }
    }
}
