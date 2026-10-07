import Foundation

public struct DiffChangeBlock: Identifiable, Equatable, Sendable {
    public var id: Int { firstRow }
    public let firstRow: Int
    public let lastRow: Int
    public let beforeLines: ClosedRange<Int>?
    public let afterLines: ClosedRange<Int>?
    /// Unmodified aligned lines since the preceding block, or from the start.
    public let gapLines: Int
    public var lineCount: Int { lastRow - firstRow + 1 }
}
