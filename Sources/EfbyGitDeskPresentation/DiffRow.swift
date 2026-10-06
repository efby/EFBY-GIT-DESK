import Foundation

public struct DiffRow: Equatable, Sendable {
    public let before: String?
    public let after: String?
    public let beforeNumber: Int?
    public let afterNumber: Int?
    public var differentEnding = false
    public var changed: Bool { before != after || differentEnding }
}
