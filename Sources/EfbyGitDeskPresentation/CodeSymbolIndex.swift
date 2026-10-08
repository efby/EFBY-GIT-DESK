import Foundation

struct CodeSymbol: Identifiable, Equatable, Sendable {
    let name: String
    let line: Int
    let before: Bool
    var owner: String? = nil
    var isType = false
    var id: String { "\(line):\(name)" }
}

struct CodeClassSpan: Equatable, Sendable {
    let name: String
    let start: Int
    let end: Int
}

/// Lightweight navigation index. It never executes code or claims to be a full language parser.
enum CodeSymbolIndex {
    static func supports(_ language: CodeLanguage) -> Bool { [.python, .javascript, .typescript, .dart].contains(language) }

    static func make(text: String, language: CodeLanguage, before: Bool = false) -> [CodeSymbol] {
        scan(text: text, language: language, before: before).symbols
    }

    static func classSpans(text: String, language: CodeLanguage) -> [CodeClassSpan] {
        scan(text: text, language: language, before: false).classes
    }

    private static func scan(text: String, language: CodeLanguage, before: Bool) -> (symbols: [CodeSymbol], classes: [CodeClassSpan]) {
        guard supports(language), text.utf8.count <= 2_000_000 else { return ([], []) }
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
        default: return ([], [])
        }
        let expressions = patterns.compactMap { try? NSRegularExpression(pattern: $0) }
        let typeExpression = try? NSRegularExpression(pattern: #"\b(?:class|interface|enum|mixin|extension)\s+([A-Za-z_$][\w$]*)"#)
        let excluded: Set<String> = ["if", "for", "while", "switch", "catch", "return", "assert", "function", "await", "new", "throw", "yield", "typeof", "void", "delete"]
        var lexer = CodeLexer(language: language)
        var result: [CodeSymbol] = []
        var classes: [CodeClassSpan] = []
        var pythonClasses: [(indent: Int, name: String, start: Int)] = []
        var braceClasses: [(depth: Int, name: String, start: Int)] = []
        var pendingType: (name: String, line: Int)?
        var depth = 0
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).prefix(20_000).map(String.init)
        func closePython(at indent: Int, line: Int) {
            while let top = pythonClasses.last, indent <= top.indent {
                pythonClasses.removeLast()
                classes.append(CodeClassSpan(name: top.name, start: top.start, end: max(top.start, line - 1)))
            }
        }
        for (offset, line) in lines.enumerated() {
            let lineNumber = offset + 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if language == .python {
                if !trimmed.isEmpty && !trimmed.hasPrefix("#") {
                    let indent = line.prefix { $0 == " " || $0 == "\t" }.count
                    closePython(at: indent, line: lineNumber)
                }
            } else {
                while let top = braceClasses.last, top.depth > depth {
                    braceClasses.removeLast()
                    classes.append(CodeClassSpan(name: top.name, start: top.start, end: max(top.start, lineNumber - 1)))
                }
            }
            let owner = language == .python ? pythonClasses.last?.name : braceClasses.last?.name
            if line.utf16.count <= 8_192 {
                let tokens = lexer.tokens(in: line)
                let range = NSRange(location: 0, length: line.utf16.count)
                for expression in expressions {
                    guard let match = expression.firstMatch(in: line, range: range) else { continue }
                    let nameRange = match.range(at: 1)
                    guard nameRange.location != NSNotFound,
                          !tokens.contains(where: { ($0.kind == .comment || $0.kind == .string) && NSIntersectionRange($0.range, nameRange).length > 0 }) else { continue }
                    let name = (line as NSString).substring(with: nameRange)
                    guard !excluded.contains(name) else { continue }
                    let typeLine = line.range(of: #"(?:class|interface|enum|mixin|extension)\s+$"#, options: .regularExpression) != nil
                        || line.range(of: "(?:class|interface|enum|mixin|extension)\\s+\(NSRegularExpression.escapedPattern(for: name))\\b", options: .regularExpression) != nil
                    result.append(CodeSymbol(name: name, line: lineNumber, before: before, owner: owner, isType: typeLine))
                    break
                }
            }
            if language == .python {
                if trimmed.range(of: #"^(?:async\s+)?class\s+([A-Za-z_]\w*)"#, options: .regularExpression) != nil,
                   let name = result.last?.name, result.last?.line == lineNumber {
                    let indent = line.prefix { $0 == " " || $0 == "\t" }.count
                    pythonClasses.append((indent, name, lineNumber))
                }
            } else if let typeExpression, let match = typeExpression.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count)),
                      match.range(at: 1).location != NSNotFound {
                pendingType = ((line as NSString).substring(with: match.range(at: 1)), lineNumber)
            }
            if language != .python {
                let delta = braceDelta(line)
                if let pending = pendingType, delta.open > 0 {
                    braceClasses.append((depth + 1, pending.name, pending.line))
                    pendingType = nil
                }
                depth = max(0, depth + delta.open - delta.close)
            }
            if result.count >= 500 { break }
        }
        let lastLine = lines.count
        for top in pythonClasses.reversed() {
            classes.append(CodeClassSpan(name: top.name, start: top.start, end: max(top.start, lastLine)))
        }
        for top in braceClasses.reversed() where top.depth <= depth {
            classes.append(CodeClassSpan(name: top.name, start: top.start, end: max(top.start, lastLine)))
        }
        return (result, classes)
    }

    private static func braceDelta(_ line: String) -> (open: Int, close: Int) {
        var open = 0
        var close = 0
        var quote: Character?
        for character in line {
            if let active = quote {
                if character == active { quote = nil }
                continue
            }
            if character == "\"" || character == "'" || character == "`" { quote = character; continue }
            if character == "{" { open += 1 }
            if character == "}" { close += 1 }
        }
        return (open, close)
    }
}
