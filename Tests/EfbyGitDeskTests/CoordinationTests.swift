import Foundation
import Testing
@testable import EfbyGitDeskApplication
import EfbyGitDeskInfrastructure
import EfbyGitDeskDomain

struct CoordinationTests {
    @Test func heldPermitSurvivesSuspensionAndSerializesWriters() async {
        let gate = OperationGate()
        let activity = Activity()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<20 {
                group.addTask {
                    await gate.acquire("repository")
                    await activity.enter()
                    try? await Task.sleep(for: .milliseconds(5))
                    await activity.leave()
                    await gate.release("repository")
                }
            }
        }
        #expect(await activity.peak == 1)
        #expect(await activity.completed == 20)
    }
    @Test func timeoutEscalatesForOwnedProcessIgnoringTermination() async throws {
        let start = ContinuousClock.now
        await #expect(throws: DeskError.self) {
            try await ProcessRunner().run(executable: "/bin/sh", arguments: ["-c", "trap '' TERM; while :; do :; done"], directory: NSTemporaryDirectory(), timeout: 0.1)
        }
        #expect(start.duration(to: .now) < .seconds(3))
    }
    @Test func inheritedPipeDoesNotKeepReaderAliveForever() async throws {
        let start = ContinuousClock.now
        let result = try await ProcessRunner().run(executable: "/bin/sh", arguments: ["-c", "sleep 2 & exit 0"], directory: NSTemporaryDirectory(), timeout: 5)
        #expect(start.duration(to: .now) < .seconds(2))
        #expect(result.truncated)
    }
}

private actor Activity {
    private var current = 0
    var peak = 0
    var completed = 0
    func enter() { current += 1; peak = max(peak, current) }
    func leave() { current -= 1; completed += 1 }
}
