import Foundation

public struct DiffSyntax: Equatable, Sendable {
    public let before: [[SyntaxToken]]
    public let after: [[SyntaxToken]]
}
