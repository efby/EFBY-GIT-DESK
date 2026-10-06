import Foundation
import EfbyGitDeskDomain
import EfbyGitDeskInfrastructure

struct GitFixture: Sendable {
    let folder: URL
    let executable: String
    let adapter: GitAdapter
    let repository: Repository
    static func make(initialCommit: Bool = true, objectFormat: String = "sha1") async throws -> GitFixture {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("EfbyGitDeskTests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let executable = ["/opt/homebrew/bin/git", "/usr/local/bin/git", "/usr/bin/git"].first { FileManager.default.isExecutableFile(atPath: $0) }!
        let runner = ProcessRunner()
        let environment = ["GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": "/dev/null"]
        for args in [
            ["init", "--initial-branch=main", "--object-format=" + objectFormat], ["config", "user.name", "Fixture"],
            ["config", "user.email", "fixture@example.invalid"], ["config", "commit.gpgsign", "false"],
            ["config", "core.hooksPath", "/dev/null"]
        ] {
            let result = try await runner.run(executable: executable, arguments: args, directory: folder.path, environment: environment)
            guard result.status == 0 else { throw DeskError("Fixture no pudo crear el repositorio.") }
        }
        let adapter = GitAdapter(executable: executable, vault: KeychainVault(), credentialHelper: "/missing", allowLocalRemotes: true)
        var repository = try await adapter.discover(path: folder.path); repository.trusted = true
        let fixture = GitFixture(folder: folder, executable: executable, adapter: adapter, repository: repository)
        if initialCommit {
            try fixture.write("README.md", "base\n")
            _ = try await fixture.git(["add", "--", "README.md"])
            _ = try await fixture.git(["commit", "-m", "Initial"])
        }
        return fixture
    }
    func git(_ arguments: [String], in directory: URL? = nil) async throws -> String {
        let result = try await ProcessRunner().run(
            executable: executable,
            arguments: ["-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "-c", "commit.gpgsign=false"] + arguments,
            directory: (directory ?? folder).path,
            environment: ["GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": "/dev/null", "GIT_TERMINAL_PROMPT": "0"])
        guard result.status == 0 else { throw DeskError(String(decoding: result.error, as: UTF8.self)) }
        return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    func write(_ name: String, _ value: String) throws { try Data(value.utf8).write(to: folder.appendingPathComponent(name)) }
    func commit(_ name: String, _ value: String, message: String) async throws -> String {
        try write(name, value); _ = try await git(["add", "--", name]); _ = try await git(["commit", "-m", message])
        return try await git(["rev-parse", "HEAD"])
    }
    func remote() async throws -> URL {
        let bare = folder.appendingPathComponent("remote.git")
        _ = try await git(["init", "--bare", "--initial-branch=main", bare.path])
        _ = try await git(["remote", "add", "origin", bare.path])
        _ = try await git(["push", "-u", "origin", "main"])
        return bare
    }
    func secondClone(remote: URL) async throws -> URL {
        let second = folder.appendingPathComponent("second")
        _ = try await git(["clone", remote.path, second.path])
        _ = try await git(["config", "core.hooksPath", "/dev/null"], in: second)
        return second
    }
    func cleanup() { try? FileManager.default.removeItem(at: folder) }
}
