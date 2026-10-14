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

private actor BulkConcurrencyRecorder {
    private var active: Set<String> = []
    private var peak = 0

    func record(_ event: BulkRepositoryProgressEvent) async {
        switch event {
        case .started(let repository, _):
            active.insert(repository.path)
            peak = max(peak, active.count)
            // Keep each worker occupied long enough to observe overlapping starts.
            try? await Task.sleep(for: .milliseconds(80))
        case .finished(let entry):
            active.remove(entry.path)
        }
    }

    func maximum() -> Int { peak }
}

@Suite(.serialized) struct BulkRepositoryOperationsTests {
    @Test func bulkTrustAndFetchUseAtMostFourIndependentRepositoriesAtOnce() async throws {
        var fixtures: [GitFixture] = []
        for _ in 0..<6 { fixtures.append(try await GitFixture.make()) }
        defer { for fixture in fixtures { fixture.cleanup() } }
        let registry = try SQLiteRegistry(path: fixtures[0].folder.appendingPathComponent("catalog.sqlite").path)
        let service = DeskService(git: fixtures[0].adapter, registry: registry, cloud: BitbucketClient(vault: KeychainVault()))
        var ids: [String] = []
        for fixture in fixtures { ids.append(try await service.open(path: fixture.folder.path).id) }
        for repository in try await registry.repositories() {
            var copy = repository
            copy.trusted = false
            try await registry.save(copy)
        }

        let trustRecorder = BulkConcurrencyRecorder()
        let trust = try await service.trustAll(ids: ids) { event in await trustRecorder.record(event) }
        #expect(trust.completed == 6)
        #expect(await trustRecorder.maximum() == 4)

        let fetchRecorder = BulkConcurrencyRecorder()
        let fetch = try await service.fetchAll(profile: nil) { event in await fetchRecorder.record(event) }
        #expect(fetch.skipped == 6)
        #expect(await fetchRecorder.maximum() == 4)
    }

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
        #expect(one.trusted && two.trusted)
        let before = try await service.fetchAll(profile: nil)
        #expect(before.completed >= 2)
        #expect(before.skipped >= 1)

        for repository in [one, two] {
            var copy = repository
            copy.trusted = false
            try await registry.save(copy)
        }
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
