import Testing
@testable import EfbyGitDeskPresentation

struct RepositoryTabClosePlanTests {
    @Test func contextualCloseTargetsRespectVisibleOrderAndKeepAnchor() {
        let tabs = ["a", "b", "c", "d"]
        #expect(RepositoryTabClosePlan.targets(in: tabs, relativeTo: "b", scope: .others) == ["a", "c", "d"])
        #expect(RepositoryTabClosePlan.targets(in: tabs, relativeTo: "b", scope: .left) == ["a"])
        #expect(RepositoryTabClosePlan.targets(in: tabs, relativeTo: "b", scope: .right) == ["c", "d"])
        #expect(RepositoryTabClosePlan.targets(in: tabs, relativeTo: "a", scope: .left).isEmpty)
        #expect(RepositoryTabClosePlan.targets(in: tabs, relativeTo: "d", scope: .right).isEmpty)
        #expect(RepositoryTabClosePlan.targets(in: tabs, relativeTo: "missing", scope: .others).isEmpty)
    }
}
