import Foundation
import Testing
import EfbyGitDeskDomain
import EfbyGitDeskApplication
import EfbyGitDeskInfrastructure
@testable import EfbyGitDeskPresentation

struct HistorySearchTests {
    @Test(arguments: ["sha1", "sha256"])
    func searchesFullAndAbbreviatedSHAWithoutAcceptingRevisions(format: String) async throws {
        let f = try await GitFixture.make(objectFormat: format); defer { f.cleanup() }
        let root = try await f.git(["rev-parse", "HEAD"])
        let head = try await f.commit("README.md", "new\n", message: "Find this message")
        for search in [root, String(root.prefix(8)), String(root.prefix(8)).uppercased(), "  " + root + "  "] {
            let commits = try await f.adapter.history(f.repository, tips: [head], offset: 0, search: search)
            #expect(commits.map(\.oid) == [root])
        }
        #expect(try await f.adapter.history(f.repository, tips: [head], offset: 0, search: head).map(\.oid) == [head])
        #expect(try await f.adapter.history(f.repository, tips: [head], offset: 0, search: "FIND THIS").map(\.oid) == [head])
        #expect(try await f.adapter.history(f.repository, tips: [head], offset: 0, search: "HEAD~1").isEmpty)
        #expect(try await f.adapter.history(f.repository, tips: [head], offset: 0, search: "--all").isEmpty)
        #expect(try await f.adapter.history(f.repository, tips: [head], offset: 100, search: root).isEmpty)
        let blob = try await f.git(["rev-parse", "HEAD:README.md"])
        #expect(try await f.adapter.history(f.repository, tips: [head], offset: 0, search: blob).isEmpty)
        let tree = try await f.git(["rev-parse", "HEAD^{tree}"])
        let unreachable = try await f.git(["commit-tree", tree, "-m", "Unreachable"])
        #expect(try await f.adapter.history(f.repository, tips: [head], offset: 0, search: unreachable).isEmpty)
    }

    @MainActor @Test func selectionAndComparisonSurviveFilteringAndClearing() async throws {
        let f = try await GitFixture.make(); defer { f.cleanup() }
        _ = try await f.commit("README.md", "new\n", message: "Second")
        let model = try await makeModel(f)
        try await wait { !model.loading && model.commits.count == 2 }
        let newer = model.commits[0], older = model.commits[1]
        model.chooseCommit(newer); model.chooseCommit(older)
        try await wait { !model.filesLoading && !model.files.isEmpty }
        let context = model.context, pair = model.orderedComparison
        for filter in [newer.shortOID, "no matching message", ""] {
            model.search = filter; model.refresh(forceHistory: true)
            try await wait { !model.loading && !model.filesLoading }
            #expect(model.selectedOIDs == [newer.oid, older.oid])
            #expect(model.orderedComparison == pair && model.context == context)
            #expect(model.commitDetails(older.oid)?.author == older.author)
            #expect(!model.files.isEmpty)
        }
        #expect(model.hiddenSelectedCommits.isEmpty)
        model.chooseCommit(older)
        #expect(model.selectedOIDs == [newer.oid])
    }

    @MainActor @Test func oldCommitRemainsSelectedBeyondFirstPage() async throws {
        let f = try await GitFixture.make(); defer { f.cleanup() }
        let root = try await f.git(["rev-parse", "HEAD"])
        let tree = try await f.git(["rev-parse", "HEAD^{tree}"])
        var parent = root
        for index in 0..<102 {
            parent = try await f.git(["commit-tree", tree, "-p", parent, "-m", "Commit \(index)"])
        }
        _ = try await f.git(["update-ref", "refs/heads/main", parent])
        let model = try await makeModel(f)
        try await wait { !model.loading && model.commits.count == 100 }
        model.search = String(root.prefix(8)); model.refresh(forceHistory: true)
        try await wait { !model.loading && model.commits.count == 1 }
        model.chooseCommit(model.commits[0])
        try await wait { !model.filesLoading }
        let context = model.context
        model.search = ""; model.refresh(forceHistory: true)
        try await wait { !model.loading && !model.filesLoading }
        #expect(model.commits.count == 100 && model.hasMore)
        #expect(model.selectedOIDs == [root] && model.context == context)
        #expect(model.hiddenSelectedCommits.map(\.oid) == [root])
        model.loadMore()
        try await wait { !model.busy && model.commits.count == 103 }
        #expect(model.hiddenSelectedCommits.isEmpty && model.selectedOIDs == [root])
    }

    @MainActor @Test(arguments: [true, false])
    func separateSearchesKeepTopologicalDirection(newerFirst: Bool) async throws {
        let f = try await GitFixture.make(); defer { f.cleanup() }
        let root = try await f.git(["rev-parse", "HEAD"])
        let head = try await f.commit("README.md", "new\n", message: "Second")
        let model = try await makeModel(f)
        try await wait { !model.loading && model.commits.count == 2 }
        for oid in newerFirst ? [head, root] : [root, head] {
            model.search = oid; model.refresh(forceHistory: true)
            try await wait { !model.loading && model.commits.count == 1 }
            model.chooseCommit(model.commits[0])
        }
        try await wait { !model.comparisonOrdering && !model.filesLoading }
        #expect(model.context == .commits(try ComparisonPair(base: root, target: head)))
        model.search = ""; model.refresh(forceHistory: true)
        try await wait { !model.loading && !model.filesLoading }
        #expect(model.context == .commits(try ComparisonPair(base: root, target: head)))
    }

    @MainActor @Test func thirdClickRequestsReplacementAndCancelKeepsPair() async throws {
        let f = try await GitFixture.make(); defer { f.cleanup() }
        _ = try await f.commit("README.md", "second\n", message: "Second")
        _ = try await f.commit("README.md", "third\n", message: "Third")
        let model = try await makeModel(f)
        try await wait { !model.loading && model.commits.count == 3 }
        let first = model.commits[0], second = model.commits[1], third = model.commits[2]
        model.chooseCommit(first); model.chooseCommit(second)
        let context = model.context
        model.chooseCommit(third)
        #expect(model.showReplaceComparison && model.pendingComparisonCommit == third)
        #expect(model.context == context && model.selectedOIDs == [first.oid, second.oid])
        model.resolveComparisonReplacement(accept: false)
        #expect(!model.showReplaceComparison && model.context == context)
        model.chooseCommit(third); model.resolveComparisonReplacement(accept: true)
        #expect(!model.showReplaceComparison && model.pendingComparisonCommit == nil)
        #expect(model.selectedOIDs == [third.oid])
        #expect(model.context == .commit(third.oid, parent: 0))
        model.chooseCommit(first)
        #expect(model.context == .commits(try ComparisonPair(base: third.oid, target: first.oid)))
    }

    @MainActor private func makeModel(_ f: GitFixture) async throws -> DeskModel {
        let registry = try SQLiteRegistry(path: f.folder.appendingPathComponent("catalog.sqlite").path)
        let service = DeskService(git: f.adapter, registry: registry, cloud: BitbucketClient(vault: KeychainVault()))
        let repo = try await service.open(path: f.folder.path)
        let model = DeskModel(service: service, terminalFactory: { PTYTerminal(shell: "/bin/sh", login: false) })
        model.repositories = [repo]; model.select(repo.id)
        return model
    }
    @MainActor private func wait(_ condition: () -> Bool) async throws {
        for _ in 0..<500 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(20))
        }
        throw DeskError("La consulta de historial no terminó a tiempo.")
    }
}
