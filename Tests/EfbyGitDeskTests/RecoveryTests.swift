import Foundation
import Testing
import EfbyGitDeskDomain
import EfbyGitDeskInfrastructure

@Suite(.serialized) struct RecoveryTests {
    @Test func exactLeaseRejectsRaceAfterLocalAmendAndPreservesBothHistories() async throws {
        let f = try await GitFixture.make(); defer { f.cleanup() }
        let old = try await f.git(["rev-parse", "HEAD"])
        let remote = try await f.remote()
        let second = try await f.secondClone(remote: remote)
        try Data("other change\n".utf8).write(to: second.appendingPathComponent("README.md"))
        _ = try await f.git(["add", "README.md"], in: second)
        _ = try await f.git(["commit", "-m", "Concurrent"], in: second)
        let concurrent = try await f.git(["rev-parse", "HEAD"], in: second)
        let plan = try await f.adapter.prepareAmend(f.repository, message: "Edited locally", publish: true, remote: "origin", profile: nil)
        let hooks = f.folder.appendingPathComponent("hooks")
        try FileManager.default.createDirectory(at: hooks, withIntermediateDirectories: true)
        let hook = hooks.appendingPathComponent("pre-push")
        let script = "#!/bin/sh\nenv -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE " + quote(f.executable) + " -c core.hooksPath=/dev/null -C " + quote(second.path) + " push origin main >/dev/null 2>&1\n"
        try Data(script.utf8).write(to: hook)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: hook.path)
        _ = try await f.git(["config", "core.hooksPath", hooks.path])
        await #expect(throws: DeskError.self) { try await f.adapter.executeAmend(plan, profile: nil) }
        let edited = try await f.git(["rev-parse", "HEAD"])
        #expect(edited != old)
        #expect(try await f.git(["show", "-s", "--format=%B", "HEAD"]) == "Edited locally")
        #expect(try await f.git(["rev-parse", plan.recoveryReference]) == old)
        #expect(try await f.git(["--git-dir=" + remote.path, "rev-parse", "refs/heads/main"]) == concurrent)
    }
    @Test func rejectingCommitHookPreservesPreparedContentAndHEAD() async throws {
        let f = try await GitFixture.make(); defer { f.cleanup() }
        let old = try await f.git(["rev-parse", "HEAD"])
        try f.write("README.md", "prepared\n")
        _ = try await f.adapter.execute(.stage([Data("README.md".utf8)]), repository: f.repository, profile: nil)
        let index = try await f.git(["write-tree"])
        let hooks = f.folder.appendingPathComponent("hooks")
        try FileManager.default.createDirectory(at: hooks, withIntermediateDirectories: true)
        let hook = hooks.appendingPathComponent("pre-commit")
        try Data("#!/bin/sh\nexit 1\n".utf8).write(to: hook)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: hook.path)
        _ = try await f.git(["config", "core.hooksPath", hooks.path])
        await #expect(throws: DeskError.self) { try await f.adapter.execute(.commit("Rejected"), repository: f.repository, profile: nil) }
        #expect(try await f.git(["rev-parse", "HEAD"]) == old)
        #expect(try await f.git(["write-tree"]) == index)
    }
    @Test func stalePlanDoesNotRewriteNewHEAD() async throws {
        let f = try await GitFixture.make(); defer { f.cleanup() }
        let plan = try await f.adapter.prepareAmend(f.repository, message: "Old plan", publish: false, remote: "", profile: nil)
        let new = try await f.commit("README.md", "new\n", message: "New HEAD")
        await #expect(throws: DeskError.self) { try await f.adapter.executeAmend(plan, profile: nil) }
        #expect(try await f.git(["rev-parse", "HEAD"]) == new)
    }
    private func quote(_ value: String) -> String { "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'" }
}
