import Foundation
import Testing
import EfbyGitDeskDomain
import EfbyGitDeskApplication
import EfbyGitDeskInfrastructure

struct ProcessAndStorageTests {
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
        try await registry.remove(id: repository.id)
        #expect(try await registry.repositories().isEmpty)
        #expect(FileManager.default.fileExists(atPath: f.folder.appendingPathComponent("README.md").path))
    }
    @Test func useCaseRequiresPersistedTrustNotJustUIFlag() async throws {
        let f = try await GitFixture.make(); defer { f.cleanup() }
        let registry = try SQLiteRegistry(path: f.folder.appendingPathComponent("catalog.sqlite").path)
        let service = DeskService(git: f.adapter, registry: registry, cloud: BitbucketClient(vault: KeychainVault()))
        let registered = try await service.open(path: f.folder.path)
        #expect(!registered.trusted)
        await #expect(throws: DeskError.self) {
            try await service.mutate(.createBranch("blocked"), repository: f.repository, profile: nil)
        }
        let trusted = try await service.trust(registered)
        _ = try await service.mutate(.createBranch("allowed"), repository: trusted, profile: nil)
        let state = try await f.adapter.snapshot(trusted)
        #expect(try await f.git(["rev-parse", "refs/heads/allowed"]) == state.head)
    }
}
