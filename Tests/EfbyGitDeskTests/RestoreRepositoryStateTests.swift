import Foundation
import Testing
import EfbyGitDeskDomain
import EfbyGitDeskInfrastructure
@testable import EfbyGitDeskPresentation

@Suite(.serialized) struct RestoreRepositoryStateTests {
    @Test func composeMessageAddsRestoreSuffixForTicket() {
        #expect(RestoreRepositoryStateMessage.compose(userInput: "PDD-1234", shortOID: "36329d37") ==
                "PDD-1234: Restore repository state to commit 36329d37")
    }
    @Test func composeMessageKeepsFullCustomText() {
        let custom = "IDS-99: Restore repository state to commit deadbeef"
        #expect(RestoreRepositoryStateMessage.compose(userInput: custom, shortOID: "36329d37") == custom)
    }
    @Test func restoreCreatesNewCommitAndPushesWithoutLosingHistory() async throws {
        let f = try await GitFixture.make(); defer { f.cleanup() }
        _ = try await f.remote()
        let first = try await f.git(["rev-parse", "HEAD"])
        _ = try await f.commit("second.txt", "second\n", message: "Second")
        _ = try await f.git(["push", "origin", "main"])
        _ = try await f.adapter.execute(
            .restoreRepositoryState(oid: first, message: "PDD-1: Restore repository state to commit \(String(first.prefix(8)))",
                                    remote: "origin", branch: "main"),
            repository: f.repository,
            profile: nil
        )
        let head = try await f.git(["rev-parse", "HEAD"])
        #expect(head != first)
        #expect(try await f.git(["show", "HEAD:README.md"]) == "base")
        #expect(!FileManager.default.fileExists(atPath: f.folder.appendingPathComponent("second.txt").path))
        let count = try await f.git(["rev-list", "--count", "HEAD"])
        #expect(count == "3")
        let remoteHead = try await f.git(["rev-parse", "HEAD"], in: f.folder.appendingPathComponent("remote.git"))
        #expect(remoteHead == head)
    }
    @Test func restoreRejectedWhenLocalCommitsAreUnpushed() async throws {
        let f = try await GitFixture.make(); defer { f.cleanup() }
        _ = try await f.remote()
        let first = try await f.git(["rev-parse", "HEAD"])
        _ = try await f.commit("local.txt", "local\n", message: "Local only")
        await #expect(throws: DeskError.self) {
            try await f.adapter.execute(
                .restoreRepositoryState(oid: first, message: "PDD-1: Restore", remote: "origin", branch: "main"),
                repository: f.repository,
                profile: nil
            )
        }
    }
    @Test func restorePreservesStagedAndUnstagedChanges() async throws {
        let f = try await GitFixture.make(); defer { f.cleanup() }
        _ = try await f.remote()
        let first = try await f.git(["rev-parse", "HEAD"])
        let head = try await f.commit("second.txt", "second\n", message: "Second")
        _ = try await f.git(["push", "origin", "main"])
        try f.write("README.md", "local\n")
        _ = try await f.git(["add", "--", "README.md"])
        let action = GitAction.restoreRepositoryState(oid: first, message: "PDD-1: Restore", remote: "origin", branch: "main")

        await #expect(throws: DeskError.self) { try await f.adapter.execute(action, repository: f.repository, profile: nil) }
        #expect(try await f.git(["show", ":README.md"]) == "local")
        #expect(try await f.git(["rev-parse", "HEAD"]) == head)

        _ = try await f.git(["restore", "--staged", "--", "README.md"])
        await #expect(throws: DeskError.self) { try await f.adapter.execute(action, repository: f.repository, profile: nil) }
        #expect(try String(contentsOf: f.folder.appendingPathComponent("README.md"), encoding: .utf8) == "local\n")
        #expect(try await f.git(["rev-parse", "HEAD"]) == head)
    }

    @Test func restorePreservesIgnoredFileThatTargetWouldAdd() async throws {
        let f = try await GitFixture.make(); defer { f.cleanup() }
        let first = try await f.commit("restore.txt", "from commit\n", message: "Add file")
        _ = try await f.remote()
        _ = try await f.git(["rm", "--", "restore.txt"])
        try f.write(".gitignore", "restore.txt\n")
        _ = try await f.git(["add", "--", ".gitignore"])
        _ = try await f.git(["commit", "-m", "Remove and ignore file"])
        _ = try await f.git(["push", "origin", "main"])
        let head = try await f.git(["rev-parse", "HEAD"])
        try f.write("restore.txt", "ignored local bytes\n")

        await #expect(throws: DeskError.self) {
            try await f.adapter.execute(
                .restoreRepositoryState(oid: first, message: "PDD-1: Restore", remote: "origin", branch: "main"),
                repository: f.repository, profile: nil)
        }
        #expect(try String(contentsOf: f.folder.appendingPathComponent("restore.txt"), encoding: .utf8) == "ignored local bytes\n")
        #expect(try await f.git(["rev-parse", "HEAD"]) == head)
    }
    @Test func restorePreservesUntrackedFileWithDifferentCaseOnCaseInsensitiveVolume() async throws {
        let f = try await GitFixture.make(); defer { f.cleanup() }
        let first = try await f.commit("Restore.txt", "from commit\n", message: "Add file")
        _ = try await f.remote()
        _ = try await f.git(["rm", "--", "Restore.txt"])
        _ = try await f.git(["commit", "-m", "Remove file"])
        _ = try await f.git(["push", "origin", "main"])
        let head = try await f.git(["rev-parse", "HEAD"])
        try f.write("restore.txt", "local bytes\n")
        // A case-sensitive test volume has no collision for these two paths.
        guard FileManager.default.fileExists(atPath: f.folder.appendingPathComponent("Restore.txt").path) else { return }
        await #expect(throws: DeskError.self) {
            try await f.adapter.execute(
                .restoreRepositoryState(oid: first, message: "PDD-1: Restore", remote: "origin", branch: "main"),
                repository: f.repository, profile: nil)
        }
        #expect(try String(contentsOf: f.folder.appendingPathComponent("restore.txt"), encoding: .utf8) == "local bytes\n")
        #expect(try await f.git(["rev-parse", "HEAD"]) == head)
    }
}
