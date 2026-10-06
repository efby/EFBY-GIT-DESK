import Foundation

public struct ComparisonPair: Hashable, Sendable {
    public let base: String
    public let target: String
    public init(base: String, target: String) throws {
        guard Self.validOID(base), Self.validOID(target), base != target else {
            throw DeskError("Selecciona exactamente dos commits distintos.")
        }
        self.base = base; self.target = target
    }
    public static func validOID(_ value: String) -> Bool {
        [40, 64].contains(value.count) && value.utf8.allSatisfy {
            (48...57).contains($0) || (97...102).contains($0)
        }
    }
    public func reversed() throws -> ComparisonPair { try ComparisonPair(base: target, target: base) }
}
