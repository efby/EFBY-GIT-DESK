import Foundation

public struct DiffInlineRow: Equatable, Sendable {
    public var before: [NSRange] = []
    public var after: [NSRange] = []
    public var limited = false
}
