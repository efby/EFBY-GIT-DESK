import Foundation
import Testing
import EfbyGitDeskApplication
import EfbyGitDeskInfrastructure
import EfbyGitDeskPresentation

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

    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while !condition() {
            guard ContinuousClock.now < deadline else { throw CocoaError(.fileReadUnknown) }
            try await Task.sleep(for: .milliseconds(20))
        }
    }
}
