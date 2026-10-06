import Foundation

public enum DiffContext: Hashable, Sendable {
    case commits(ComparisonPair)
    case staged
    case working
    case commit(String, parent: Int)
}
