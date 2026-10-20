import Foundation

public struct DiffRow: Equatable, Sendable {
    public let before: String?
    public let after: String?
    public let beforeNumber: Int?
    public let afterNumber: Int?
    public var differentEnding = false
    public var changed: Bool { contentChanged || differentEnding }
    public var contentChanged: Bool {
        guard let before, let after else { return before != after }
        return Self.comparableContent(before) != Self.comparableContent(after)
    }
    public var lineEndingChanged: Bool {
        guard let before, let after else { return false }
        return before != after && Self.comparableContent(before) == Self.comparableContent(after)
    }
    static func comparableContent(_ line: String) -> String {
        line.hasSuffix("\r") ? String(line.dropLast()) : line
    }
}
