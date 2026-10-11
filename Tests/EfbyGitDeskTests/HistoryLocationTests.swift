import Testing
import EfbyGitDeskDomain
@testable import EfbyGitDeskPresentation

struct HistoryLocationTests {
    @Test func localAndTrackingRemoteRemainDistinctWhenRemoteIsAhead() {
        let local = String(repeating: "a", count: 40)
        let remote = String(repeating: "b", count: 40)
        let state = RepositorySnapshot(head: local, branch: "master", upstream: "origin/master", ahead: 0, behind: 6)
        let branches = [
            Branch(reference: "refs/heads/master", oid: local, upstream: "origin/master", current: true),
            Branch(reference: "refs/remotes/origin/master", oid: remote, upstream: "", current: false)
        ]
        let location = HistoryLocation(snapshot: state, branches: branches)
        #expect(location.localOID == local)
        #expect(location.localName == "master")
        #expect(location.remoteOID == remote)
        #expect(location.remoteName == "origin/master")
        #expect(location.behind == 6)
        #expect(location.accessibilitySuffix(for: local).contains("6 commits detrás"))
        #expect(location.accessibilitySuffix(for: remote).contains("commit remoto"))
    }

    @Test func bothMarkersCanShareOneCommitAndMissingTrackingHasNoInventedDistance() {
        let oid = String(repeating: "c", count: 40)
        let branch = Branch(reference: "refs/remotes/origin/main", oid: oid, upstream: "", current: false)
        let tracked = HistoryLocation(snapshot: RepositorySnapshot(head: oid, branch: "main", upstream: "origin/main", ahead: 0, behind: 0), branches: [branch])
        #expect(tracked.localOID == tracked.remoteOID)
        let untracked = HistoryLocation(snapshot: RepositorySnapshot(head: oid, branch: "main"), branches: [branch])
        #expect(untracked.remoteOID == nil)
        #expect(untracked.behind == nil)
    }
}
