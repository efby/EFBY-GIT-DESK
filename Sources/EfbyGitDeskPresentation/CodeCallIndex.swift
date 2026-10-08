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

    static func links(rows: [DiffRow], beforeLanguage: CodeLanguage, afterLanguage: CodeLanguage,
                      declarations: [CodeDeclaration], currentFileID: String) -> CodeCallLinks {
        CodeCallLinks(
            before: rows.map { links(in: $0.before, line: $0.beforeNumber, language: beforeLanguage, declarations: declarations, currentFileID: currentFileID) },
            after: rows.map { links(in: $0.after, line: $0.afterNumber, language: afterLanguage, declarations: declarations, currentFileID: currentFileID) }
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
            URLQueryItem(name: "name", value: link.name)
        ]
        return components.url
    }

    static func target(from link: Any) -> (fileID: String, line: Int, before: Bool, name: String)? {
        guard let url = link as? URL, url.scheme == "efbygitdesk", url.host == "symbol",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let fileID = items.first(where: { $0.name == "file" })?.value,
              let line = items.first(where: { $0.name == "line" })?.value.flatMap(Int.init),
              let before = items.first(where: { $0.name == "before" })?.value else { return nil }
        let name = items.first(where: { $0.name == "name" })?.value ?? ""
        return (fileID, line, before == "1", name)
    }

    private static func links(in content: String?, line: Int?, language: CodeLanguage,
                              declarations: [CodeDeclaration], currentFileID: String) -> [CodeCallLink] {
        guard let content, let line, CodeSymbolIndex.supports(language) else { return [] }
        var lexer = CodeLexer(language: language)
        let hidden = lexer.tokens(in: content).filter { $0.kind == .comment || $0.kind == .string }.map(\.range)
        let expression = try? NSRegularExpression(pattern: #"([A-Za-z_$][\w$]*(?:\.[A-Za-z_$][\w$]*)*)\s*\("#)
        let range = NSRange(location: 0, length: content.utf16.count)
        guard let expression else { return [] }
        return expression.matches(in: content, range: range).compactMap { match in
            let nameRange = match.range(at: 1)
            guard nameRange.location != NSNotFound,
                  !hidden.contains(where: { NSIntersectionRange($0, nameRange).length > 0 }) else { return nil }
            let written = (content as NSString).substring(with: nameRange)
            let parts = written.split(separator: ".").map(String.init)
            guard let name = parts.last, !["if", "for", "while", "switch", "catch", "return", "assert", "function"].contains(name) else { return nil }
            let qualifier = parts.count > 1 ? parts.dropLast().joined(separator: ".") : nil
            guard let declaration = resolve(name: name, qualifier: qualifier, declarations: declarations, currentFileID: currentFileID),
                  declaration.fileID != currentFileID || declaration.line != line else { return nil }
            return CodeCallLink(range: nameRange, fileID: declaration.fileID, path: declaration.path,
                                name: declaration.name, line: declaration.line, before: declaration.before)
        }
    }

    static func resolve(name: String, qualifier: String?, declarations: [CodeDeclaration], currentFileID: String) -> CodeDeclaration? {
        let matches = declarations.filter { $0.name == name }
        let hint = qualifier?.split(separator: ".").last.map(String.init)
        if let hint, !ignoredQualifiers.contains(hint) {
            let hinted = matches.filter { pathStems($0.path).contains(hint) }
            if hinted.count == 1 { return hinted[0] }
            if hinted.count > 1 { return nil }
        }
        let local = matches.filter { $0.fileID == currentFileID }
        if local.count == 1 { return local[0] }
        return matches.count == 1 ? matches[0] : nil
    }

    private static func pathStems(_ path: String) -> Set<String> {
        Set(path.split(separator: "/").map { part in
            let name = String(part)
            if let dot = name.lastIndex(of: ".") { return String(name[..<dot]) }
            return name
        })
    }
}
