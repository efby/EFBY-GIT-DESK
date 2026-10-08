import Foundation
import EfbyGitDeskDomain

struct CodeDeclaration: Equatable, Sendable {
    let fileID: String
    let path: String
    let name: String
    let line: Int
    let before: Bool
}

struct CodeCallLink: Equatable, Sendable {
    let range: NSRange
    let fileID: String
    let path: String
    let name: String
    let line: Int
    let before: Bool
    let callLine: Int
}

struct CodeCallLinks: Equatable, Sendable {
    let before: [[CodeCallLink]]
    let after: [[CodeCallLink]]
}

/// Resolves a call written in the viewer to the declaration that contains it.
enum CodeCallIndex {
    private static let ignoredQualifiers: Set<String> = ["self", "cls", "this", "super"]

    static func declarations(file: FileChange, text: String, before: Bool) -> [CodeDeclaration] {
        let language = CodeLanguage.detect(path: file.name)
        return CodeSymbolIndex.make(text: text, language: language, before: before).map {
            CodeDeclaration(fileID: file.id, path: file.name, name: $0.name, line: $0.line, before: before)
        }
    }

    static func fingerprint(_ text: String) -> Int {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Int(truncatingIfNeeded: hash)
    }

    static func callNames(rows: [DiffRow], beforeLanguage _: CodeLanguage, afterLanguage: CodeLanguage) -> [String] {
        var qualified: [String] = []
        var plain: [String] = []
        var seen = Set<String>()
        for row in rows {
            for occurrence in occurrences(in: row.after, language: afterLanguage) {
                guard seen.insert(occurrence.name).inserted else { continue }
                if occurrence.qualifier != nil { qualified.append(occurrence.name) }
                else { plain.append(occurrence.name) }
            }
        }
        return Array((qualified + plain).prefix(80))
    }

    static func links(rows: [DiffRow], beforeLanguage _: CodeLanguage, afterLanguage: CodeLanguage,
                      declarations: [CodeDeclaration], currentFileID: String, imports: [String: String] = [:]) -> CodeCallLinks {
        CodeCallLinks(
            before: Array(repeating: [], count: rows.count),
            after: rows.map { links(in: $0.after, line: $0.afterNumber, language: afterLanguage, declarations: declarations, currentFileID: currentFileID, imports: imports) }
        )
    }

    static func url(for link: CodeCallLink) -> URL? {
        var components = URLComponents()
        components.scheme = "efbygitdesk"
        components.host = "symbol"
        components.queryItems = [
            URLQueryItem(name: "file", value: link.fileID),
            URLQueryItem(name: "line", value: String(link.line)),
            URLQueryItem(name: "before", value: link.before ? "1" : "0"),
            URLQueryItem(name: "name", value: link.name),
            URLQueryItem(name: "call", value: String(link.callLine))
        ]
        return components.url
    }

    static func target(from link: Any) -> (fileID: String, line: Int, before: Bool, name: String, callLine: Int)? {
        guard let url = link as? URL, url.scheme == "efbygitdesk", url.host == "symbol",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let fileID = items.first(where: { $0.name == "file" })?.value,
              let line = items.first(where: { $0.name == "line" })?.value.flatMap(Int.init),
              let before = items.first(where: { $0.name == "before" })?.value else { return nil }
        let name = items.first(where: { $0.name == "name" })?.value ?? ""
        let callLine = items.first(where: { $0.name == "call" })?.value.flatMap(Int.init) ?? line
        return (fileID, line, before == "1", name, callLine)
    }

    private static func occurrences(in content: String?, language: CodeLanguage) -> [(name: String, qualifier: String?, range: NSRange)] {
        guard let content, CodeSymbolIndex.supports(language) else { return [] }
        var lexer = CodeLexer(language: language)
        let hidden = lexer.tokens(in: content).filter { $0.kind == .comment || $0.kind == .string }.map(\.range)
        let expression = try? NSRegularExpression(pattern: #"([A-Za-z_$][\w$]*(?:\??\.[A-Za-z_$][\w$]*)*)(?:\s*<[^;\n]{0,200}>)?\s*\("#)
        let range = NSRange(location: 0, length: content.utf16.count)
        guard let expression else { return [] }
        return expression.matches(in: content, range: range).compactMap { match in
            let nameRange = match.range(at: 1)
            guard nameRange.location != NSNotFound,
                  !hidden.contains(where: { NSIntersectionRange($0, nameRange).length > 0 }) else { return nil }
            let written = (content as NSString).substring(with: nameRange)
            let parts = written.replacingOccurrences(of: "?.", with: ".").split(separator: ".").map(String.init)
            guard let name = parts.last, !["if", "for", "while", "switch", "catch", "return", "assert", "function"].contains(name) else { return nil }
            let qualifier = parts.count > 1 ? parts.dropLast().joined(separator: ".") : nil
            return (name, qualifier, nameRange)
        }
    }

    private static func links(in content: String?, line: Int?, language: CodeLanguage,
                              declarations: [CodeDeclaration], currentFileID: String, imports: [String: String]) -> [CodeCallLink] {
        guard let line else { return [] }
        return occurrences(in: content, language: language).compactMap { occurrence in
            let name = occurrence.name
            let qualifier = occurrence.qualifier
            let nameRange = occurrence.range
            guard let declaration = resolve(name: name, qualifier: qualifier, declarations: declarations, currentFileID: currentFileID, imports: imports),
                  declaration.fileID != currentFileID || declaration.line != line else { return nil }
            return CodeCallLink(range: nameRange, fileID: declaration.fileID, path: declaration.path,
                                name: declaration.name, line: declaration.line, before: declaration.before, callLine: line)
        }
    }

    static func resolve(name: String, qualifier: String?, declarations: [CodeDeclaration], currentFileID: String, imports: [String: String] = [:]) -> CodeDeclaration? {
        let matches = declarations.filter { $0.name == name }
        let hint = qualifier?.split(separator: ".").last.map(String.init)
        if let hint, !ignoredQualifiers.contains(hint), let imported = imports[normalize(hint)] {
            let hinted = matches.filter { CodeImportIndex.moduleMatches(file: $0.path, module: imported) }
            if hinted.count == 1 { return hinted[0] }
            if hinted.count > 1 { return nil }
        }
        if let imported = imports[normalize(name)] {
            let hinted = matches.filter { CodeImportIndex.moduleMatches(file: $0.path, module: imported) }
            if hinted.count == 1 { return hinted[0] }
            if hinted.count > 1 { return nil }
        }
        if let hint, !ignoredQualifiers.contains(hint) {
            let wanted = normalize(hint)
            let hinted = matches.filter { pathStems($0.path).contains { normalize($0) == wanted } }
            if hinted.count == 1 { return hinted[0] }
            if hinted.count > 1 { return nil }
        }
        let local = matches.filter { $0.fileID == currentFileID }
        if local.count == 1 { return local[0] }
        return matches.count == 1 ? matches[0] : nil
    }

    static func isDeclarationLine(_ text: String, name: String) -> Bool {
        guard let range = text.range(of: name), text[range.upperBound...].contains("(") else { return false }
        let previous = text[..<range.lowerBound].last
        return previous != "." && previous != "$"
    }

    private static func normalize(_ value: String) -> String {
        String(value.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
    }

    private static func pathStems(_ path: String) -> Set<String> {
        Set(path.split(separator: "/").map { part in
            let name = String(part)
            if let dot = name.lastIndex(of: ".") { return String(name[..<dot]) }
            return name
        })
    }
}
