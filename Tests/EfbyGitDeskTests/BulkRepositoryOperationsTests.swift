import Foundation
import Testing
import EfbyGitDeskApplication
import EfbyGitDeskInfrastructure

private actor BulkProgressRecorder {
    private var events: [String] = []

    func record(_ event: BulkRepositoryProgressEvent) {
        switch event {
        case .started(let repository, let remote):
            events.append("start:\(repository.id):\(remote ?? "")")
        case .finished(let entry):
            events.append("finish:\(entry.path):\(entry.remote ?? "")")
        }
    }

    func snapshot() -> [String] { events }
}

@Suite(.serialized) struct BulkRepositoryOperationsTests {
    @Test func trustsRegisteredRepositoriesThenFetchesEveryRemoteAndReportsSkips() async throws {
        let first = try await GitFixture.make(); defer { first.cleanup() }
        let second = try await GitFixture.make(); defer { second.cleanup() }
        let remote = try await first.remote()
        _ = try await first.git(["remote", "add", "backup", remote.path])
        _ = try await first.git(["remote", "add", "unsupported", "https://github.com/example/repository.git"])
        let another = try await first.secondClone(remote: remote)
        _ = try await first.git(["-C", another.path, "config", "user.name", "Fixture"])
        _ = try await first.git(["-C", another.path, "config", "user.email", "fixture@example.invalid"])
        try Data("new\n".utf8).write(to: another.appendingPathComponent("new.txt"))
        _ = try await first.git(["add", "--", "new.txt"], in: another)
        _ = try await first.git(["commit", "-m", "New"], in: another)
        _ = try await first.git(["push", "origin", "main"], in: another)

        let registry = try SQLiteRegistry(path: first.folder.appendingPathComponent("catalog.sqlite").path)
        let service = DeskService(git: first.adapter, registry: registry, cloud: BitbucketClient(vault: KeychainVault()))
        let one = try await service.open(path: first.folder.path)
        let two = try await service.open(path: second.folder.path)
        let before = try await service.fetchAll(profile: nil)
        #expect(before.skipped == 2)
        #expect(before.completed == 0)

        let trustRecorder = BulkProgressRecorder()
        let trusted = try await service.trustAll(ids: [one.id, two.id]) { event in await trustRecorder.record(event) }
        #expect(trusted.completed == 2)
        #expect(try await registry.repositories().allSatisfy(\.trusted))
        let trustEvents = await trustRecorder.snapshot()
        #expect(trustEvents.count == 4)
        for repository in [one, two] {
            let start = trustEvents.firstIndex(of: "start:\(repository.id):")
            let finish = trustEvents.firstIndex(of: "finish:\(repository.path):")
            #expect(start != nil && finish != nil && start! < finish!)
        }
        let recorder = BulkProgressRecorder()
        let fetched = try await service.fetchAll(profile: nil) { event in await recorder.record(event) }
        #expect(fetched.completed == 2)
        #expect(fetched.skipped == 1)
        #expect(fetched.failed == 1)
        #expect(fetched.entries.contains { $0.remote == "unsupported" && $0.result == .failed })
        let events = await recorder.snapshot()
        #expect(events.filter { $0.hasPrefix("finish:") }.count == fetched.entries.count)
        for remoteName in ["backup", "origin", "unsupported"] {
            let start = events.firstIndex(of: "start:\(one.id):\(remoteName)")
            let finish = events.firstIndex(of: "finish:\(one.path):\(remoteName)")
            #expect(start != nil && finish != nil && start! < finish!)
        }
        let remoteHead = try await first.git(["rev-parse", "refs/heads/main"], in: remote)
        #expect(try await first.git(["rev-parse", "refs/remotes/origin/main"]) == remoteHead)
        #expect(try await first.git(["rev-parse", "refs/remotes/backup/main"]) == remoteHead)
    }

    @Test func bulkTrustRejectsReplacedRepositoryIdentity() async throws {
        let fixture = try await GitFixture.make(); defer { fixture.cleanup() }
        let registry = try SQLiteRegistry(path: fixture.folder.appendingPathComponent("catalog.sqlite").path)
        let service = DeskService(git: fixture.adapter, registry: registry, cloud: BitbucketClient(vault: KeychainVault()))
        let registered = try await service.open(path: fixture.folder.path)
        let oldGit = fixture.folder.appendingPathComponent(".git")
        try FileManager.default.moveItem(at: oldGit, to: fixture.folder.appendingPathComponent("old-git"))
        _ = try await fixture.git(["init", "--initial-branch=main"])
        let result = try await service.trustAll(ids: [registered.id])
        #expect(result.completed == 0)
        #expect(result.failed == 1)
        #expect(try await registry.repositories().first?.trusted == false)
    }
}
