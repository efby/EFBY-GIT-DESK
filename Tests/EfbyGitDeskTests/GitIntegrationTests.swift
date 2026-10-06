import Foundation
import Testing
import EfbyGitDeskDomain
import EfbyGitDeskApplication
import EfbyGitDeskInfrastructure

@Suite(.serialized) struct GitIntegrationTests {
    @Test func commitIncludesOnlyPreparedBytesAndTreatsMessageAsData() async throws {
        let f = try await GitFixture.make(); defer { f.cleanup() }
        try f.write("README.md", "unstaged work\n")
        let name = "-archivo\ncon espacio.txt"
        try f.write(name, "prepared work\n")
        _ = try await f.adapter.execute(.stage([Data(name.utf8)]), repository: f.repository, profile: nil)
        _ = try await f.adapter.execute(.commit("Literal $(touch NO_EJECUTAR)"), repository: f.repository, profile: nil)
        #expect(try await f.git(["show", "HEAD:README.md"]) == "base")
        #expect(try await f.git(["show", "HEAD:" + name]) == "prepared work")
        #expect(!FileManager.default.fileExists(atPath: f.folder.appendingPathComponent("NO_EJECUTAR").path))
        #expect(try String(contentsOf: f.folder.appendingPathComponent("README.md"), encoding: .utf8) == "unstaged work\n")
    }
    @Test func initialCommitAndUnstageWorkWithoutHEAD() async throws {
        let f = try await GitFixture.make(initialCommit: false); defer { f.cleanup() }
        try f.write("new.txt", "first\n")
        let action = GitAction.stage([Data("new.txt".utf8)])
        _ = try await f.adapter.execute(action, repository: f.repository, profile: nil)
        _ = try await f.adapter.execute(.unstage([Data("new.txt".utf8)]), repository: f.repository, profile: nil)
        #expect(try await f.adapter.snapshot(f.repository).files.allSatisfy { !$0.staged })
        _ = try await f.adapter.execute(action, repository: f.repository, profile: nil)
        _ = try await f.adapter.execute(.commit("First"), repository: f.repository, profile: nil)
        #expect(try await f.adapter.snapshot(f.repository).head.count == 40)
    }
    @Test func untrustedInspectionDoesNotRunWorkingTreeTools() async throws {
        let f = try await GitFixture.make(); defer { f.cleanup() }
        var repository = f.repository; repository.trusted = false
        let marker = f.folder.appendingPathComponent("marker")
        let script = f.folder.appendingPathComponent("evil")
        try Data("#!/bin/sh\ntouch '\(marker.path)'\n".utf8).write(to: script)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: script.path)
        _ = try await f.git(["config", "core.fsmonitor", script.path])
        let state = try await f.adapter.snapshot(repository)
        #expect(!state.head.isEmpty); #expect(state.files.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: marker.path))
        await #expect(throws: DeskError.self) {
            try await f.adapter.execute(.stage([Data("README.md".utf8)]), repository: repository, profile: nil)
        }
    }
    @Test func comparesDirectTreesForUnrelatedRootsAndMerges() async throws {
        let f = try await GitFixture.make(); defer { f.cleanup() }
        let root = try await f.git(["rev-parse", "HEAD"])
        _ = try await f.git(["checkout", "--orphan", "other"])
        _ = try await f.git(["rm", "-f", "--", "README.md"])
        let other = try await f.commit("other.txt", "other\n", message: "Other root")
        let pair = try ComparisonPair(base: root, target: other)
        let files = try await f.adapter.changes(f.repository, context: .commits(pair))
        #expect(Set(files.map(\.name)) == ["README.md", "other.txt"])
        _ = try await f.git(["checkout", "main"])
        _ = try await f.git(["checkout", "-b", "feature"])
        let feature = try await f.commit("feature.txt", "feature\n", message: "Feature")
        _ = try await f.git(["checkout", "main"])
        _ = try await f.commit("main.txt", "main\n", message: "Main")
        _ = try await f.git(["merge", "--no-ff", "feature", "-m", "Merge"])
        let merge = try await f.git(["rev-parse", "HEAD"])
        let direct = try await f.adapter.changes(f.repository, context: .commits(ComparisonPair(base: feature, target: merge)))
        #expect(direct.map(\.name) == ["main.txt"])
        let history = try await f.adapter.history(f.repository, tips: [merge], offset: 0, search: "")
        #expect(history.first?.parents.count == 2)
    }
    @Test func rootCommitDiffAndBinaryRenameInventoryAreComplete() async throws {
        let f = try await GitFixture.make(); defer { f.cleanup() }
        let root = try await f.git(["rev-parse", "HEAD"])
        #expect(try await f.adapter.changes(f.repository, context: .commit(root, parent: 0)).map(\.name) == ["README.md"])
        _ = try await f.git(["mv", "README.md", "renamed.md"])
        try Data([0, 1, 2, 3, 0]).write(to: f.folder.appendingPathComponent("binary.dat"))
        _ = try await f.git(["add", "--", "binary.dat"])
        _ = try await f.git(["commit", "-m", "Rename and binary"])
        let head = try await f.git(["rev-parse", "HEAD"])
        let files = try await f.adapter.changes(f.repository, context: .commits(ComparisonPair(base: root, target: head)))
        #expect(files.count == 2)
        #expect(files.contains { $0.name == "renamed.md" && $0.oldPath == Data("README.md".utf8) })
        let binary = files.first { $0.name == "binary.dat" }!
        #expect(try await f.adapter.diff(f.repository, context: .commits(ComparisonPair(base: root, target: head)), file: binary).contains("Binary"))
    }
    @Test func publishedAmendPreservesTreeAuthorAndRecovery() async throws {
        let f = try await GitFixture.make(); defer { f.cleanup() }
        let bare = try await f.remote()
        let old = try await f.git(["rev-parse", "HEAD"])
        let tree = try await f.git(["rev-parse", "HEAD^{tree}"])
        let plan = try await f.adapter.prepareAmend(f.repository, message: "Corrected\n\nBody", publish: true, remote: "origin", profile: nil)
        _ = try await f.adapter.executeAmend(plan, profile: nil)
        let head = try await f.git(["rev-parse", "HEAD"])
        #expect(head != old)
        #expect(try await f.git(["rev-parse", "HEAD^{tree}"]) == tree)
        #expect(try await f.git(["rev-parse", plan.recoveryReference]) == old)
        #expect(try await f.git(["rev-parse", "refs/heads/main"], in: bare) == head)
        #expect(try await f.adapter.message(f.repository, oid: head).contains("Body"))
    }
    @Test func remoteAdvanceInvalidatesAmendWithoutChangingLocalHEAD() async throws {
        let f = try await GitFixture.make(); defer { f.cleanup() }
        let bare = try await f.remote()
        let second = try await f.secondClone(remote: bare)
        let old = try await f.git(["rev-parse", "HEAD"])
        let plan = try await f.adapter.prepareAmend(f.repository, message: "Corrected", publish: true, remote: "origin", profile: nil)
        try Data("remote\n".utf8).write(to: second.appendingPathComponent("remote.txt"))
        _ = try await f.git(["add", "--", "remote.txt"], in: second)
        _ = try await f.git(["commit", "-m", "Remote advancement"], in: second)
        _ = try await f.git(["push", "origin", "main"], in: second)
        await #expect(throws: DeskError.self) { try await f.adapter.executeAmend(plan, profile: nil) }
        #expect(try await f.git(["rev-parse", "HEAD"]) == old)
    }
    @Test func stagedChangesBlockAmendAndExternalLockIsPreserved() async throws {
        let f = try await GitFixture.make(); defer { f.cleanup() }
        try f.write("README.md", "staged\n")
        _ = try await f.adapter.execute(.stage([Data("README.md".utf8)]), repository: f.repository, profile: nil)
        await #expect(throws: DeskError.self) {
            try await f.adapter.prepareAmend(f.repository, message: "No", publish: false, remote: "", profile: nil)
        }
        let lock = f.folder.appendingPathComponent(".git/index.lock")
        try Data("external".utf8).write(to: lock)
        await #expect(throws: DeskError.self) {
            try await f.adapter.execute(.stage([Data("README.md".utf8)]), repository: f.repository, profile: nil)
        }
        #expect(FileManager.default.fileExists(atPath: lock.path))
    }
    @Test func cloneRejectsExistingDestinationsAndNeedsTrustBeforeCheckout() async throws {
        let f = try await GitFixture.make(); defer { f.cleanup() }
        let bare = try await f.remote()
        let destination = f.folder.appendingPathComponent("cloned")
        var cloned = try await f.adapter.clone(source: bare.path, destination: destination.path, profile: nil)
        #expect(!cloned.trusted); #expect(cloned.pendingCheckout)
        #expect(!FileManager.default.fileExists(atPath: destination.appendingPathComponent("README.md").path))
        await #expect(throws: DeskError.self) { try await f.adapter.materializeClone(cloned) }
        cloned.trusted = true
        try await f.adapter.materializeClone(cloned)
        #expect(FileManager.default.fileExists(atPath: destination.appendingPathComponent("README.md").path))
        await #expect(throws: DeskError.self) {
            try await f.adapter.clone(source: bare.path, destination: destination.path, profile: nil)
        }
    }
    @Test func pullDivergenceDoesNotMergeOrDiscardLocalWork() async throws {
        let f = try await GitFixture.make(); defer { f.cleanup() }
        let bare = try await f.remote()
        let second = try await f.secondClone(remote: bare)
        _ = try await f.commit("local.txt", "local\n", message: "Local")
        let localHead = try await f.git(["rev-parse", "HEAD"])
        try Data("remote\n".utf8).write(to: second.appendingPathComponent("remote.txt"))
        _ = try await f.git(["add", "--", "remote.txt"], in: second)
        _ = try await f.git(["commit", "-m", "Remote"], in: second)
        _ = try await f.git(["push", "origin", "main"], in: second)
        await #expect(throws: DeskError.self) { try await f.adapter.execute(.pull("origin"), repository: f.repository, profile: nil) }
        #expect(try await f.git(["rev-parse", "HEAD"]) == localHead)
        #expect(!FileManager.default.fileExists(atPath: f.folder.appendingPathComponent(".git/MERGE_HEAD").path))
        #expect(try String(contentsOf: f.folder.appendingPathComponent("local.txt"), encoding: .utf8) == "local\n")
    }
    @Test func unsupportedProviderCannotReceiveNetworkOperations() async throws {
        let f = try await GitFixture.make(); defer { f.cleanup() }
        _ = try await f.git(["remote", "add", "origin", "https://github.com/example/repository.git"])
        #expect(await f.adapter.remoteSupported(f.repository, remote: "origin") == false)
        await #expect(throws: DeskError.self) {
            try await f.adapter.execute(.fetch("origin"), repository: f.repository, profile: nil)
        }
    }
}
