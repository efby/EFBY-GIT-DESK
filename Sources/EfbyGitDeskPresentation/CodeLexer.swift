import Foundation

/// A bounded lexical highlighter, not a compiler or executable language service.
struct CodeLexer {
    let language: CodeLanguage
    private let keywords: Set<String>
    private var stringEnd: [UInt16]?
    private var multilineString = false
    private var commentEnd: [UInt16]?
    private var tokenCount = 0

    init(language: CodeLanguage) { self.language = language; keywords = language.keywords }
    mutating func tokens(in line: String) -> [SyntaxToken] {
        guard language != .plain && language != .automatic, tokenCount < 60_000 else { return [] }
        let units = Array(line.utf16)
        var result: [SyntaxToken] = [], position = 0
        func matches(_ sequence: [UInt16], at index: Int) -> Bool {
            index + sequence.count <= units.count && units[index..<(index + sequence.count)].elementsEqual(sequence)
        }
        func identifier(_ unit: UInt16) -> Bool { unit == 95 || (65...90).contains(unit) || (97...122).contains(unit) || unit >= 128 }
        func digit(_ unit: UInt16) -> Bool { (48...57).contains(unit) }
        func add(_ start: Int, _ end: Int, _ kind: SyntaxKind) {
            if end > start { result.append(SyntaxToken(range: NSRange(location: start, length: end - start), kind: kind)) }
        }
        while position < units.count && tokenCount + result.count < 60_000 {
            let start = position
            if let end = commentEnd {
                while position < units.count && !matches(end, at: position) { position += 1 }
                if position < units.count { position += end.count; commentEnd = nil }
                add(start, position, .comment); continue
            }
            if let end = stringEnd {
                while position < units.count {
                    if units[position] == 92 { position = min(position + 2, units.count); continue }
                    if matches(end, at: position) { position += end.count; stringEnd = nil; break }
                    position += 1
                }
                add(start, position, .string); continue
            }
            let unit = units[position]
            if (language.hashComments && unit == 35) ||
                (language.slashComments && matches([47, 47], at: position)) ||
                (language == .sql && matches([45, 45], at: position)) {
                add(position, units.count, .comment); position = units.count; continue
            }
            if (language.slashComments || language == .sql) && matches([47, 42], at: position) {
                commentEnd = [42, 47]; position += 2
                // Include the opener in the same token as this line's comment body.
                while position < units.count && !matches([42, 47], at: position) { position += 1 }
                if position < units.count { position += 2; commentEnd = nil }
                add(start, position, .comment); continue
            }
            if language == .html && matches([60, 33, 45, 45], at: position) {
                commentEnd = [45, 45, 62]; position += 4
                while position < units.count && !matches([45, 45, 62], at: position) { position += 1 }
                if position < units.count { position += 3; commentEnd = nil }
                add(start, position, .comment); continue
            }
            if language == .markdown && (unit == 35 || unit == 62) {
                add(position, units.count, .tag); position = units.count; continue
            }
            if unit == 34 || unit == 39 || (unit == 96 && [.javascript, .typescript, .markdown, .shell].contains(language)) {
                let triple = language == .python && matches([unit, unit, unit], at: position)
                let end = triple ? [unit, unit, unit] : [unit]
                multilineString = triple || unit == 96 || [.ruby, .shell].contains(language)
                stringEnd = end; position += end.count
                while position < units.count {
                    if units[position] == 92 { position = min(position + 2, units.count); continue }
                    if matches(end, at: position) { position += end.count; stringEnd = nil; break }
                    position += 1
                }
                add(start, position, .string); continue
            }
            if unit == 64 && [.python, .swift, .java, .kotlin, .typescript, .css].contains(language) {
                position += 1
                while position < units.count && (identifier(units[position]) || digit(units[position]) || units[position] == 46) { position += 1 }
                add(start, position, .decorator); continue
            }
            if digit(unit) {
                position += 1
                while position < units.count && (digit(units[position]) || units[position] == 46 || units[position] == 95 || (65...70).contains(units[position]) || (97...102).contains(units[position]) || units[position] == 120) { position += 1 }
                add(start, position, .number); continue
            }
            if identifier(unit) || (unit == 36 && [.javascript, .typescript, .shell].contains(language)) {
                position += 1
                while position < units.count && (identifier(units[position]) || digit(units[position]) || units[position] == 36) { position += 1 }
                let word = String(decoding: units[start..<position], as: UTF16.self)
                var next = position
                while next < units.count && [9, 32].contains(units[next]) { next += 1 }
                if keywords.contains(language == .sql ? word.lowercased() : word) { add(start, position, .keyword) }
                else if language == .html && start > 0 && (units[start - 1] == 60 || (units[start - 1] == 47 && start > 1 && units[start - 2] == 60)) { add(start, position, .tag) }
                else if next < units.count && units[next] == 40 { add(start, position, .function) }
                else if (65...90).contains(unit) { add(start, position, .type) }
                continue
            }
            position += 1
        }
        if !multilineString && units.last != 92 { stringEnd = nil }
        tokenCount += result.count
        return result
    }
}
