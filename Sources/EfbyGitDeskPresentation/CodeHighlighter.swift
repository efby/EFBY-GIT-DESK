import Foundation

public enum CodeHighlighter {
    public static func highlight(rows: [DiffRow], before: CodeLanguage, after: CodeLanguage) -> DiffSyntax {
        var left = CodeLexer(language: before), right = CodeLexer(language: after)
        var a: [[SyntaxToken]] = [], b: [[SyntaxToken]] = []
        a.reserveCapacity(rows.count); b.reserveCapacity(rows.count)
        for row in rows {
            a.append(row.before.map { left.tokens(in: $0) } ?? [])
            b.append(row.after.map { right.tokens(in: $0) } ?? [])
        }
        return DiffSyntax(before: a, after: b)
    }
}
