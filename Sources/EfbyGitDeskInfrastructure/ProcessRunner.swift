import Foundation
import Darwin
import EfbyGitDeskDomain

public struct ProcessRunner: Sendable {
    // ProcessJob waits for OS processes and pipe readers. It must not occupy
    // Swift's cooperative executor, whose threads other async work needs.
    private static let processQueue = DispatchQueue(label: "cl.efby.gitdesk.process", qos: .userInitiated, attributes: .concurrent)
    public init() {}
    public func run(executable: String, arguments: [String], directory: String,
                    input: Data? = nil, environment: [String: String] = [:],
                    limit: Int = 16 * 1024 * 1024, timeout: TimeInterval = 90) async throws -> ProcessResult {
        let job = ProcessJob(executable: executable, arguments: arguments, directory: directory,
                             input: input, environment: environment, limit: limit, timeout: timeout)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                Self.processQueue.async {
                    continuation.resume(with: Result { try job.run() })
                }
            }
        } onCancel: { job.cancel() }
    }
}
