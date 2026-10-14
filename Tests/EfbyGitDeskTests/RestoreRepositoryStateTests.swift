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
}
