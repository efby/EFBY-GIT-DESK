import Foundation

public struct GraphRow: Sendable {
    public let lane: Int
    public let before: [String]
    public let after: [String]
    public let parents: [String]
}
