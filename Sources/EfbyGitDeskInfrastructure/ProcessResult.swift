import Foundation

public struct ProcessResult: Sendable {
    public let status: Int32
    public let output: Data
    public let error: Data
    public let truncated: Bool
    public var text: String { String(decoding: output, as: UTF8.self) }
}
