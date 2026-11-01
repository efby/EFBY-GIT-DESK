import Foundation
import Testing
import EfbyGitDeskDomain
import EfbyGitDeskApplication
import EfbyGitDeskInfrastructure

struct ProcessAndStorageTests {
    @Test func concurrentProcessesDoNotStarvePipeReaders() async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<24 {
                group.addTask {
                    let input = Data(repeating: 120, count: 128 * 1024)
                    let result = try await ProcessRunner().run(
                        executable: "/bin/sh", arguments: ["-c", "cat; printf 'stderr complete' >&2"],
                        directory: NSTemporaryDirectory(), input: input, timeout: 10
                    )
                    #expect(result.status == 0)
                    #expect(result.output == input)
                    #expect(String(decoding: result.error, as: UTF8.self) == "stderr complete")
                }
            }
            try await group.waitForAll()
        }
    }
    @Test func processDrainsBothPipesWithoutDeadlock() async throws {
        let result = try await ProcessRunner().run(executable: "/bin/sh", arguments: [
            "-c", "i=0; while [ \"$i\" -lt 12000 ]; do printf 'stdout line\\n'; printf 'stderr line\\n' >&2; i=$((i+1)); done"
        ], directory: NSTemporaryDirectory(), timeout: 10)
        #expect(result.status == 0)
        #expect(result.output.count > 65_536)
        #expect(result.error.count > 65_536)
    }
    @Test func timeoutAndCancellationTerminateManagedProcess() async throws {
        await #expect(throws: DeskError.self) {
            try await ProcessRunner().run(executable: "/bin/sleep", arguments: ["20"], directory: NSTemporaryDirectory(), timeout: 0.15)
        }
        let task = Task { try await ProcessRunner().run(executable: "/bin/sleep", arguments: ["20"], directory: NSTemporaryDirectory()) }
        try await Task.sleep(for: .milliseconds(100)); task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
    }
    @Test func registryRoundTripsAndRemovingRegistrationPreservesFiles() async throws {
        let f = try await GitFixture.make(); defer { f.cleanup() }
        let path = f.folder.appendingPathComponent("catalog.sqlite").path
        let registry = try SQLiteRegistry(path: path)
        var repository = f.repository; repository.favorite = true; repository.group = "Work"
        try await registry.save(repository)
        #expect(try await registry.repositories().first == repository)
        try await registry.setPreference("terminal.height", value: "270")
        let reopened = try SQLiteRegistry(path: path)
        #expect(try await reopened.preference("terminal.height") == "270")
        // Sidebar metadata must update the latest registration, not a stale row
        // that could restore trust after an identity change.
        var revoked = repository; revoked.trusted = false
        try await registry.save(revoked)
        let favorite = try await registry.toggleFavorite(id: repository.id)
        #expect(!favorite.trusted && !favorite.favorite)
        let grouped = try await registry.setGroup(id: repository.id, group: "New group")
        #expect(!grouped.trusted && grouped.group == "New group")
        #expect(try await reopened.repositories().first?.trusted == false)
        try await registry.remove(id: repository.id)
        #expect(try await registry.repositories().isEmpty)
        #expect(FileManager.default.fileExists(atPath: f.folder.appendingPathComponent("README.md").path))
    }
    @Test func useCaseRequiresPersistedTrustNotJustUIFlag() async throws {
        let f = try await GitFixture.make(); defer { f.cleanup() }
        let registry = try SQLiteRegistry(path: f.folder.appendingPathComponent("catalog.sqlite").path)
        let service = DeskService(git: f.adapter, registry: registry, cloud: BitbucketClient(vault: KeychainVault()))
        let registered = try await service.open(path: f.folder.path)
        #expect(registered.trusted)
        _ = try await service.mutate(.createBranch("allowed"), repository: registered, profile: nil)
        let state = try await f.adapter.snapshot(registered)
        #expect(try await f.git(["rev-parse", "refs/heads/allowed"]) == state.head)
    }
}
