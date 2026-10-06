import Foundation
import Testing
import EfbyGitDeskInfrastructure

struct PerformanceTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["EFBY_BENCHMARK"] == "1"))
    func firstPageFromOneHundredThousandCommits() async throws {
        let f = try await GitFixture.make(initialCommit: false); defer { f.cleanup() }
        var input = Data()
        for index in 1...100_000 {
            let message = "Fixture commit \(index)"
            input.append(Data("commit refs/heads/main\nmark :\(index)\ncommitter Fixture <fixture@example.invalid> \(1_700_000_000 + index) +0000\ndata \(message.utf8.count)\n\(message)\n\n".utf8))
        }
        input.append(Data("done\n".utf8))
        let importResult = try await ProcessRunner().run(executable: f.executable, arguments: ["fast-import", "--quiet"], directory: f.folder.path,
            input: input, environment: ["GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_NOSYSTEM": "1"], timeout: 90)
        #expect(importResult.status == 0)
        #expect(try await f.git(["rev-list", "--count", "HEAD"]) == "100000")
        let oid = try await f.git(["rev-parse", "HEAD"])
        var durations: [Double] = []
        for _ in 0..<6 {
            let start = ContinuousClock.now
            let commits = try await f.adapter.history(f.repository, tips: [oid], offset: 0, search: "")
            let elapsed = start.duration(to: .now).components
            durations.append(Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18)
            #expect(commits.count == 100)
        }
        #expect(durations.dropFirst().allSatisfy { $0 < 2 })
        if let path = ProcessInfo.processInfo.environment["EFBY_BENCHMARK_REPORT"] {
            let result: [String: Any] = ["commits": 100_000, "historyPage": 100, "seconds": durations, "configuration": "debug", "coldOSCacheControlled": false, "uiInteractionMeasured": false]
            try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]).write(to: URL(fileURLWithPath: path))
        }
    }
}
