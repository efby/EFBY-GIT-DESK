import Foundation
import Darwin
import EfbyGitDeskDomain

public struct ProcessRunner: Sendable {
    public init() {}
    public func run(executable: String, arguments: [String], directory: String,
                    input: Data? = nil, environment: [String: String] = [:],
                    limit: Int = 16 * 1024 * 1024, timeout: TimeInterval = 90) async throws -> ProcessResult {
        let job = ProcessJob(executable: executable, arguments: arguments, directory: directory,
                             input: input, environment: environment, limit: limit, timeout: timeout)
        return try await withTaskCancellationHandler {
            try await Task.detached(priority: .userInitiated) { try job.run() }.value
        } onCancel: { job.cancel() }
    }
}
