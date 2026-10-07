import Foundation

public struct SyntaxToken: Equatable, Sendable {
    public let range: NSRange
    public let kind: SyntaxKind
}
