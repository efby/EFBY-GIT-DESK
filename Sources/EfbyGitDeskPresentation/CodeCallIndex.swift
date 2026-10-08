import Foundation
import EfbyGitDeskDomain

struct CodeDeclaration: Equatable, Sendable {
    let fileID: String
    let path: String
    let name: String
    let line: Int
    let before: Bool
    var owner: String? = nil
    var isType = false
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
            CodeDeclaration(fileID: file.id, path: file.name, name: $0.name, line: $0.line, before: before, owner: $0.owner, isType: $0.isType)
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
        var types: [String] = []
        var qualified: [String] = []
        var plain: [String] = []
        var seen = Set<String>()
        for row in rows {
            for occurrence in occurrences(in: row.after, language: afterLanguage) {
                guard seen.insert(occurrence.name).inserted else { continue }
                if occurrence.qualifier != nil && !isTypeName(occurrence.name) { qualified.append(occurrence.name) }
                else if isTypeName(occurrence.name) { types.append(occurrence.name) }
                else { plain.append(occurrence.name) }
            }
        }
        return Array((qualified + types + plain).prefix(80))
    }

    static func links(rows: [DiffRow], beforeLanguage _: CodeLanguage, afterLanguage: CodeLanguage,
                      declarations: [CodeDeclaration], currentFileID: String, imports: [String: String] = [:],
                      receivers: [String: String] = [:], libraries: [String] = [], classes: [CodeClassSpan] = []) -> CodeCallLinks {
        CodeCallLinks(
            before: Array(repeating: [], count: rows.count),
            after: rows.map { links(in: $0.after, line: $0.afterNumber, language: afterLanguage, declarations: declarations, currentFileID: currentFileID, imports: imports, receivers: receivers, libraries: libraries, classes: classes) }
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
        var pieces = expression.matches(in: content, range: range).flatMap { match -> [(name: String, qualifier: String?, range: NSRange)] in
            let nameRange = match.range(at: 1)
            guard nameRange.location != NSNotFound,
                  !hidden.contains(where: { NSIntersectionRange($0, nameRange).length > 0 }) else { return [] }
            let written = (content as NSString).substring(with: nameRange)
            let source = written as NSString
            let parts = written.replacingOccurrences(of: "?.", with: ".").split(separator: ".").map(String.init)
            guard let name = parts.last, !["if", "for", "while", "switch", "catch", "return", "assert", "function"].contains(name) else { return [] }
            var cursor = 0
            var pieces: [(name: String, qualifier: String?, range: NSRange)] = []
            for (index, part) in parts.enumerated() {
                let found = source.range(of: part, range: NSRange(location: cursor, length: source.length - cursor))
                guard found.location != NSNotFound else { continue }
                cursor = NSMaxRange(found)
                let isCall = index == parts.count - 1
                if !isCall && !isTypeName(part) { continue }
                let qualifier = index == 0 ? nil : parts[..<index].joined(separator: ".")
                pieces.append((part, qualifier, NSRange(location: nameRange.location + found.location, length: found.length)))
            }
            return pieces
        }
        pieces.append(contentsOf: typeReferences(in: content, language: language, hidden: hidden, range: range))
        pieces = withoutOverlap(pieces)
        var seen = Set<String>()
        return pieces.filter { seen.insert("\($0.range.location):\($0.range.length):\($0.name)").inserted }
    }

    /// A class written before its method, as in `DynamoDb.obtiene_datos_preautorizacion(`, keeps only its own characters.
    private static func withoutOverlap(_ pieces: [(name: String, qualifier: String?, range: NSRange)]) -> [(name: String, qualifier: String?, range: NSRange)] {
        pieces.compactMap { piece in
            var range = piece.range
            let cut = pieces.compactMap { other -> Int? in
                guard other.range.location > range.location, NSIntersectionRange(range, other.range).length > 0 else { return nil }
                return other.range.location
            }.min()
            if let cut { range.length = cut - range.location }
            guard range.length > 0 else { return nil }
            return (piece.name, piece.qualifier, range)
        }
    }

    /// Type names written in a constructor, annotation or generic. They are not calls.
    private static func typeReferences(in content: String, language: CodeLanguage, hidden: [NSRange], range: NSRange) -> [(name: String, qualifier: String?, range: NSRange)] {
        let pattern: String
        switch language {
        case .javascript, .typescript:
            pattern = #"(?::\s*|extends\s+|implements\s+|new\s+|<)([A-Z][A-Za-z0-9_]*)"#
        case .python:
            pattern = #"(?::\s*|\[)([A-Z][A-Za-z0-9_]*)"#
        case .dart:
            pattern = #"(?::\s*|extends\s+|implements\s+|with\s+|new\s+|<)([A-Z][A-Za-z0-9_]*)"#
        default:
            return []
        }
        let ignored: Set<String> = ["String", "Number", "Boolean", "Object", "Array", "Promise", "Record", "Partial", "Readonly", "Map", "Set", "Date", "Error", "Function", "Symbol", "BigInt", "RegExp"]
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        return expression.matches(in: content, range: range).compactMap { match in
            let nameRange = match.range(at: 1)
            guard nameRange.location != NSNotFound,
                  !hidden.contains(where: { NSIntersectionRange($0, nameRange).length > 0 }) else { return nil }
            let name = (content as NSString).substring(with: nameRange)
            guard !ignored.contains(name) else { return nil }
            return (name, nil, nameRange)
        }
    }

    private static func isTypeName(_ name: String) -> Bool {
        guard let first = name.unicodeScalars.first else { return false }
        return CharacterSet.uppercaseLetters.contains(first)
    }

    private static func links(in content: String?, line: Int?, language: CodeLanguage,
                              declarations: [CodeDeclaration], currentFileID: String, imports: [String: String],
                              receivers: [String: String], libraries: [String], classes: [CodeClassSpan]) -> [CodeCallLink] {
        guard let line else { return [] }
        return occurrences(in: content, language: language).compactMap { occurrence in
            let name = occurrence.name
            let qualifier = occurrence.qualifier
            let nameRange = occurrence.range
            guard let declaration = resolve(name: name, qualifier: qualifier, declarations: declarations, currentFileID: currentFileID, imports: imports, receivers: receivers, libraries: libraries, classes: classes, line: line),
                  declaration.fileID != currentFileID || declaration.line != line else { return nil }
            return CodeCallLink(range: nameRange, fileID: declaration.fileID, path: declaration.path,
                                name: declaration.name, line: declaration.line, before: declaration.before, callLine: line)
        }
    }

    static func resolve(name: String, qualifier: String?, declarations: [CodeDeclaration], currentFileID: String, imports: [String: String] = [:], receivers: [String: String] = [:], libraries: [String] = [], classes: [CodeClassSpan] = [], line: Int = 0) -> CodeDeclaration? {
        let seekingMethod = qualifier != nil && !isTypeName(name)
        var matches = declarations.filter { $0.name == name && (!seekingMethod || !$0.isType) }
        let hintedType = linkedType(qualifier: qualifier, receivers: receivers, classes: classes, imports: imports, line: line)
            ?? qualifier?.split(separator: ".").last.map(String.init)
        if seekingMethod, let typeName = hintedType, isTypeName(typeName) {
            let classLines = declarations.filter { $0.isType && normalize($0.name) == normalize(typeName) }
            let kept = matches.filter { method in
                let onClassLine = classLines.contains { $0.fileID == method.fileID && $0.line == method.line }
                return !onClassLine || !matches.contains { $0.fileID == method.fileID && $0.line != method.line }
            }
            if !kept.isEmpty { matches = kept }
        }
        if let typeName = linkedType(qualifier: qualifier, receivers: receivers, classes: classes, imports: imports, line: line) {
            let boundInConstructor = receiverBinding(qualifier, receivers: receivers) != nil
            if let module = imports[normalize(typeName)] {
                let imported = matches.filter { CodeImportIndex.moduleMatches(file: $0.path, module: module) }
                if !imported.isEmpty {
                    let classFiles = Set(declarations.filter { $0.isType && normalize($0.name) == normalize(typeName) }.map(\.fileID))
                    let inClass = imported.filter { classFiles.contains($0.fileID) }
                    let pool = inClass.isEmpty ? imported : inClass
                    let owned = pool.filter { $0.owner.map { normalize($0) == normalize(typeName) } ?? false }
                    return (owned.isEmpty ? pool : owned).min { $0.line < $1.line }
                }
                if boundInConstructor { return nil }
            }
            let classFiles = Set(declarations.filter { $0.isType && normalize($0.name) == normalize(typeName) }.map(\.fileID))
            let typed = matches.filter { declaration in
                if let owner = declaration.owner { return normalize(owner) == normalize(typeName) }
                if classFiles.contains(declaration.fileID) { return true }
                return libraries.contains { CodeImportIndex.moduleMatches(file: declaration.path, module: $0) }
            }
            let owned = typed.filter { $0.owner != nil }
            if owned.count == 1 { return owned[0] }
            if owned.count > 1 { return nil }
            if typed.count == 1 { return typed[0] }
            if boundInConstructor || typed.count > 1 { return nil }
        }
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

    private static func receiverBinding(_ qualifier: String?, receivers: [String: String]) -> String? {
        guard let qualifier else { return nil }
        let key = qualifier.split(separator: ".").map { $0.lowercased() }.joined(separator: ".")
        return receivers[key]
    }

    private static func linkedType(qualifier: String?, receivers: [String: String], classes: [CodeClassSpan], imports: [String: String], line: Int) -> String? {
        guard let qualifier else { return nil }
        let parts = qualifier.split(separator: ".").map(String.init)
        guard let hint = parts.last else { return nil }
        if parts.count == 1, ignoredQualifiers.contains(hint) {
            return classes.last { line >= $0.start && line <= $0.end }?.name
        }
        let key = parts.map { $0.lowercased() }.joined(separator: ".")
        if let type = receivers[key] { return type }
        if parts.count == 1, imports[normalize(hint)] != nil || classes.contains(where: { normalize($0.name) == normalize(hint) }) {
            return hint
        }
        return nil
    }

    static func isDeclarationLine(_ text: String, name: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: name)
        let patterns = [
            "(^|[^A-Za-z0-9_$.])((async|export|public|private|protected|static|abstract|override|readonly|factory|external)[[:space:]]+)*(def|class|function|interface|enum|mixin|extension)[[:space:]]+\(escaped)([^A-Za-z0-9_$]|$)",
            "(^|[^A-Za-z0-9_$.])\(escaped)[[:space:]]*(<[^;]{0,200}>)?[[:space:]]*\\([^;\\n]{0,200}\\)[[:space:]]*(->|[[:space:]]*:|[[:space:]]*\\{|[[:space:]]*=>)",
            "^[[:space:]]*((public|private|protected|static|async|override|abstract|readonly|get|set|export|declare|default)[[:space:]]+)*\(escaped)[[:space:]]*(<[^;(]{0,80}>)?[[:space:]]*\\("
        ]
        return patterns.contains { text.range(of: $0, options: .regularExpression) != nil }
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
