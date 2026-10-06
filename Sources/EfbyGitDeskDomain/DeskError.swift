import Foundation

public struct DeskError: Error, LocalizedError, Sendable, Equatable {
    public let message: String
    public var errorDescription: String? { message }
    public init(_ message: String) { self.message = message }
}
