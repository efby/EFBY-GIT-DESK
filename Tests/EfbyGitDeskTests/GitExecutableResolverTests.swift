import Foundation
import Testing
import EfbyGitDeskDomain
import EfbyGitDeskInfrastructure
import EfbyGitDeskApplication
@testable import EfbyGitDeskPresentation

struct GitExecutableResolverTests {
    @Test func collectsStandardPathsAndSkipsRelativePATHEntries() {
        let paths = GitExecutableResolver.candidates(path: "/usr/bin::.:bin:/Users/fixture/bin:/usr/local/bin:/usr/local/bin", home: "/Users/fixture")
        #expect(paths.contains("/usr/bin/git"))
        #expect(paths.contains("/Users/fixture/bin/git"))
        #expect(paths.filter { $0 == "/usr/local/bin/git" }.count == 1)
        #expect(paths.contains("/Users/fixture/.local/bin/git"))
        #expect(paths.contains("/usr/local/git/bin/git"))
        #expect(GitExecutableResolver.isAppleProvidedGit("/Applications/Xcode.app/Contents/Developer/usr/bin/git"))
        #expect(GitExecutableResolver.isAppleProvidedGit("/Library/Developer/CommandLineTools/usr/bin/git"))
    }

    @Test func fallsBackFromAnInvalidCandidate() async throws {
        let folder = try temporaryFolder(); defer { try? FileManager.default.removeItem(at: folder) }
        let invalid = folder.appendingPathComponent("invalid"), valid = folder.appendingPathComponent("valid")
        try makeGit(in: invalid, output: "not git")
        try makeGit(in: valid, output: "git version 2.51.0")
        let result = try await GitExecutableResolver().resolve(path: [invalid.path, valid.path].joined(separator: ":"), home: folder.path)
        #expect(result == valid.appendingPathComponent("git").path)
    }

    @Test func acceptsPreferredPathWhenVersionIsValid() async throws {
        let folder = try temporaryFolder(); defer { try? FileManager.default.removeItem(at: folder) }
        let developer = folder.appendingPathComponent("Xcode.app/Contents/Developer/usr/bin")
        try makeGit(in: developer, output: "git version 2.51.0")
        let path = developer.appendingPathComponent("git").path
        #expect(try await GitExecutableResolver().resolve(preferred: path) == path)
    }

    @Test func configuredPathWithSpacesIsValidatedWithoutShellAndKeptOnFailure() async throws {
        let folder = try temporaryFolder(); defer { try? FileManager.default.removeItem(at: folder) }
        let valid = folder.appendingPathComponent("user tools"), old = folder.appendingPathComponent("old")
        try makeGit(in: valid, output: "git version 2.51.0")
        try makeGit(in: old, output: "git version 2.39.0")
        let adapter = GitAdapter(vault: KeychainVault(), credentialHelper: "/missing")
        let path = valid.appendingPathComponent("git").path
        try await adapter.configureExecutable(path: path)
        #expect(try await adapter.executablePath() == path)
        #expect(try await adapter.version() == "git version 2.51.0")
        await #expect(throws: DeskError.self) { try await adapter.configureExecutable(path: old.appendingPathComponent("git").path) }
        #expect(try await adapter.executablePath() == path)
        await #expect(throws: DeskError.self) { try await adapter.configureExecutable(path: "git") }
    }

    @MainActor @Test func savedUserGitIsAppliedBeforeReopeningRepositories() async throws {
        let f = try await GitFixture.make(); defer { f.cleanup() }
        let registry = try SQLiteRegistry(path: f.folder.appendingPathComponent("catalog.sqlite").path)
        let saved = try await f.adapter.discover(path: f.folder.path)
        try await registry.save(saved)
        try await registry.setPreference("repository.selected", value: saved.id)
        let git = f.executable
        try await registry.setPreference("git.executable", value: git)
        let adapter = GitAdapter(vault: KeychainVault(), credentialHelper: "/missing")
        let service = DeskService(git: adapter, registry: registry, cloud: BitbucketClient(vault: KeychainVault()))
        let model = DeskModel(service: service, terminalFactory: { PTYTerminal(shell: "/bin/sh", login: false) })
        await model.load()
        #expect(model.error == nil)
        #expect(model.gitExecutable == git)
        #expect(model.selectedID == saved.id)
        for _ in 0..<300 {
            if !model.loading { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(model.commits.count == 1)
    }

    @MainActor @Test func unavailableSavedGitLeavesCatalogAndSettingsUsable() async throws {
        let f = try await GitFixture.make(); defer { f.cleanup() }
        let registry = try SQLiteRegistry(path: f.folder.appendingPathComponent("catalog.sqlite").path)
        let saved = try await f.adapter.discover(path: f.folder.path)
        try await registry.save(saved)
        let broken = f.folder.appendingPathComponent("missing-git").path
        try await registry.setPreference("git.executable", value: broken)
        let service = DeskService(git: GitAdapter(vault: KeychainVault(), credentialHelper: "/missing"),
            registry: registry, cloud: BitbucketClient(vault: KeychainVault()))
        let model = DeskModel(service: service, terminalFactory: { PTYTerminal(shell: "/bin/sh", login: false) })
        await model.load()
        #expect(model.repositories.map(\.id) == [saved.id])
        #expect(model.gitVersion.isEmpty && model.error != nil)
        #expect(try await f.git(["status", "--porcelain"]).contains("catalog.sqlite"))
        #expect(try await f.git(["rev-list", "--count", "HEAD"]) == "1")
    }

    @Test func findsMiniforgeWithoutTerminalPATHAndKeepsPreferredGitFirst() async throws {
        let folder = try temporaryFolder(); defer { try? FileManager.default.removeItem(at: folder) }
        let miniforge = folder.appendingPathComponent("miniforge3/bin")
        let preferred = folder.appendingPathComponent("preferred/bin")
        let apple = folder.appendingPathComponent("Library/Developer/CommandLineTools/usr/bin")
        try makeGit(in: miniforge, output: "git version 2.55.0")
        try makeGit(in: preferred, output: "git version 2.51.0")
        try makeGit(in: apple, output: "git version 2.52.0")
        let resolver = GitExecutableResolver()
        #expect(try await resolver.resolve(path: [apple.path, miniforge.path].joined(separator: ":"), home: folder.path)
            == miniforge.appendingPathComponent("git").path)
        #expect(try await resolver.resolve(preferred: preferred.appendingPathComponent("git").path,
            path: "/usr/bin:/bin", home: folder.path) == preferred.appendingPathComponent("git").path)
        #expect(try await resolver.resolve(path: preferred.path, home: folder.path)
            == preferred.appendingPathComponent("git").path)
    }

    private func temporaryFolder() throws -> URL {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("GitResolver-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        return path
    }
    private func makeGit(in folder: URL, output: String) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("git")
        try Data(("#!/bin/sh\nprintf '%s\\n' '" + output + "'\n").utf8).write(to: file)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: file.path)
    }
}
