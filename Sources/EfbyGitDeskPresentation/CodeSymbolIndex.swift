import Foundation

struct CodeSymbol: Identifiable, Equatable, Sendable {
    let name: String
    let line: Int
    let before: Bool
    var id: String { "\(line):\(name)" }
}

/// Lightweight navigation index. It never executes code or claims to be a full language parser.
enum CodeSymbolIndex {
    static func supports(_ language: CodeLanguage) -> Bool { [.python, .javascript, .typescript, .dart].contains(language) }

    static func make(text: String, language: CodeLanguage, before: Bool = false) -> [CodeSymbol] {
        guard supports(language), text.utf8.count <= 2_000_000 else { return [] }
        let patterns: [String]
        switch language {
        case .python:
            patterns = [#"^\s*(?:async\s+)?(?:def|class)\s+([A-Za-z_]\w*)\b"#]
        case .javascript, .typescript:
            patterns = [
                #"^\s*(?:(?:export|default|declare|async|public|private|protected|static|override|abstract|readonly)\s+)*(?:function\s*\*?|class\s+|interface\s+|type\s+|enum\s+)([A-Za-z_$][\w$]*)\b"#,
                #"^\s*(?:export\s+)?(?:declare\s+)?(?:const|let|var)\s+([A-Za-z_$][\w$]*)\b(?:(?!=).)*=\s*(?:async\s*)?(?:<[^=>]*>\s*)?(?:\([^)]*\)|[A-Za-z_$][\w$]*)\s*(?::(?:(?!=>)[^=])+)?\s*=>"#,
                #"^\s*(?:(?:public|private|protected|static|override|abstract|async|readonly|get|set)\s+)*([A-Za-z_$][\w$]*)\s*(?:<[^;>]*>)?\s*\([^;]*\)\s*(?::[^{=]+)?(?:\{|=>|$)"#,
                #"^\s*(?:(?:public|private|protected|static|override|abstract|async|readonly|get|set)\s+)*([A-Za-z_$][\w$]*)\s*(?:<[^;>]*>)?\s*\(\s*$"#
            ]
        case .dart:
            patterns = [#"^\s*(?:(?:external|static|abstract|factory)\s+)*(?:(?:[A-Za-z_]\w*(?:<[^>]+>)?[?]?)\s+)?([A-Za-z_]\w*)\s*\([^;]*\)\s*(?:async\*?|sync\*?)?\s*(?:\{|=>)"#,
                        #"^\s*(?:abstract\s+)?(?:class|mixin|extension|enum)\s+([A-Za-z_]\w*)\b"#]
        default: return []
        }
        let expressions = patterns.compactMap { try? NSRegularExpression(pattern: $0) }
        let excluded: Set<String> = ["if", "for", "while", "switch", "catch", "return", "assert", "function", "await", "new", "throw", "yield", "typeof", "void", "delete"]
        var lexer = CodeLexer(language: language)
        var result: [CodeSymbol] = []
        for (offset, part) in text.split(separator: "\n", omittingEmptySubsequences: false).prefix(20_000).enumerated() {
            let line = String(part)
            guard line.utf16.count <= 8_192 else { continue }
            let tokens = lexer.tokens(in: line)
            let range = NSRange(location: 0, length: line.utf16.count)
            for expression in expressions {
                guard let match = expression.firstMatch(in: line, range: range) else { continue }
                let nameRange = match.range(at: 1)
                guard nameRange.location != NSNotFound,
                      !tokens.contains(where: { ($0.kind == .comment || $0.kind == .string) && NSIntersectionRange($0.range, nameRange).length > 0 }) else { continue }
                let name = (line as NSString).substring(with: nameRange)
                guard !excluded.contains(name) else { continue }
                result.append(CodeSymbol(name: name, line: offset + 1, before: before))
                break
            }
            if result.count >= 500 { break }
        }
        return result
    }
}
