import Foundation
import Testing
import EfbyGitDeskDomain
import EfbyGitDeskApplication
import EfbyGitDeskInfrastructure

@Suite(.serialized) struct CompatibilityTests {
    @Test func sshDoesNotRequireManagedAPICredentialOrAskpassHelper() async throws {
        let f = try await GitFixture.make(); defer { f.cleanup() }
        let executable = f.folder.appendingPathComponent("fixture-transport")
        try Data("#!/bin/sh\npwd >&2\nprintf 'Fixture SSH transport reached' >&2\nexit 1\n".utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
        let adapter = GitAdapter(executable: executable.path, vault: KeychainVault(), credentialHelper: "/missing")
        let profile = ConnectionProfile(id: "missing-fixture", email: "fixture@example.invalid")
        do {
            _ = try await adapter.clone(source: "git@bitbucket.org:demo/repository.git", destination: f.folder.appendingPathComponent("clone").path, profile: profile)
            Issue.record("The deliberately failing fixture transport should report an error.")
        } catch let error as DeskError {
            #expect(error.message.contains("Fixture SSH transport reached"))
            #expect(!error.message.contains(f.folder.path))
            #expect(error.message.contains("EfbyGitDeskClone-"))
        }
    }
    @Test func replacingGitDirectoryRevokesRememberedTrust() async throws {
        let f = try await GitFixture.make(); defer { f.cleanup() }
        let registry = try SQLiteRegistry(path: f.folder.appendingPathComponent("catalog.sqlite").path)
        let service = DeskService(git: f.adapter, registry: registry, cloud: BitbucketClient(vault: KeychainVault()))
        let opened = try await service.open(path: f.folder.path)
        let trusted = try await service.trust(opened)
        try FileManager.default.moveItem(at: f.folder.appendingPathComponent(".git"), to: f.folder.appendingPathComponent("old.git"))
        _ = try await f.git(["init", "-b", "main"])
        await #expect(throws: DeskError.self) { try await f.adapter.snapshot(trusted) }
        let reopened = try await service.open(path: f.folder.path)
        #expect(!reopened.trusted)
        #expect(reopened.identity != trusted.identity)
    }
    @Test func sha256RepositorySupportsHistoryAndComparison() async throws {
        let f = try await GitFixture.make(objectFormat: "sha256"); defer { f.cleanup() }
        let old = try await f.git(["rev-parse", "HEAD"])
        let new = try await f.commit("README.md", "SHA-256\n", message: "New")
        #expect(old.count == 64 && new.count == 64)
        let history = try await f.adapter.history(f.repository, tips: [new], offset: 0, search: "")
        #expect(history.count == 2)
        let files = try await f.adapter.changes(f.repository, context: .commits(try ComparisonPair(base: old, target: new)))
        #expect(files.map(\.name) == ["README.md"])
    }
    @Test func unstageRenameRestoresEntireIndexWithoutMovingWorkingFiles() async throws {
        let f = try await GitFixture.make(); defer { f.cleanup() }
        _ = try await f.git(["mv", "README.md", "Renamed.md"])
        let state = try await f.adapter.snapshot(f.repository)
        let rename = try #require(state.files.first)
        #expect(rename.oldPath == Data("README.md".utf8))
        _ = try await f.adapter.execute(.unstage([rename.path, try #require(rename.oldPath)]), repository: f.repository, profile: nil)
        #expect(try await f.adapter.snapshot(f.repository).files.allSatisfy { !$0.staged })
        #expect(FileManager.default.fileExists(atPath: f.folder.appendingPathComponent("Renamed.md").path))
    }
    @Test func blockedCheckoutPreservesUncommittedBytesAndBranch() async throws {
        let f = try await GitFixture.make(); defer { f.cleanup() }
        _ = try await f.git(["switch", "-c", "other"])
        _ = try await f.commit("README.md", "other branch\n", message: "Other")
        _ = try await f.git(["switch", "main"])
        try f.write("README.md", "local work\n")
        await #expect(throws: DeskError.self) { try await f.adapter.execute(.checkout("other"), repository: f.repository, profile: nil) }
        #expect(try await f.git(["branch", "--show-current"]) == "main")
        #expect(try String(contentsOf: f.folder.appendingPathComponent("README.md"), encoding: .utf8) == "local work\n")
    }
    @Test func shallowAndLinkedWorktreeAreInspectedWithoutMutation() async throws {
        let f = try await GitFixture.make(); defer { f.cleanup() }
        let remote = try await f.remote()
        let shallow = f.folder.appendingPathComponent("shallow")
        _ = try await f.git(["clone", "--depth=1", "file://" + remote.path, shallow.path])
        var restricted = try await f.adapter.discover(path: shallow.path); restricted.trusted = true
        #expect(restricted.inspectionReason != nil)
        await #expect(throws: DeskError.self) { try await f.adapter.execute(.createBranch("blocked"), repository: restricted, profile: nil) }
        let linked = f.folder.appendingPathComponent("linked")
        _ = try await f.git(["worktree", "add", "-b", "linked", linked.path])
        var worktree = try await f.adapter.discover(path: linked.path); worktree.trusted = true
        #expect(worktree.linkedWorktree)
        await #expect(throws: DeskError.self) { try await f.adapter.execute(.createBranch("blocked"), repository: worktree, profile: nil) }
    }
}
