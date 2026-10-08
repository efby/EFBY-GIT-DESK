import Foundation

struct CodeFileScope: Equatable, Sendable {
    var imports: [String: String]
    var receivers: [String: String]
    var libraries: [String]
    static let empty = CodeFileScope(imports: [:], receivers: [:], libraries: [])
}

/// Maps a name written in the open file to the module path declared by its import.
enum CodeImportIndex {
    static func scope(in source: String, language: CodeLanguage, filePath: String) -> CodeFileScope {
        CodeFileScope(imports: bindings(in: source, language: language, filePath: filePath), receivers: receivers(in: source, language: language), libraries: libraries(in: source, language: language, filePath: filePath))
    }

    static func bindings(in source: String, language: CodeLanguage, filePath: String) -> [String: String] {
        guard CodeSymbolIndex.supports(language), source.utf8.count <= 2_000_000 else { return [:] }
        var bound: [String: String] = [:]
        func add(_ name: String, _ module: String) {
            let key = normalize(name)
            guard !key.isEmpty, !module.isEmpty else { return }
            if let existing = bound[key], existing != module { bound[key] = ""; return }
            bound[key] = module
        }
        switch language {
        case .javascript, .typescript:
            collectScripts(source, filePath: filePath, add: add)
        case .python:
            collectPython(source, filePath: filePath, add: add)
        case .dart:
            collectDart(source, filePath: filePath, add: add)
        default:
            break
        }
        return bound.filter { !$0.value.isEmpty }
    }

    /// Binds an instance name to the class constructed or declared for it.
    static func receivers(in source: String, language: CodeLanguage) -> [String: String] {
        guard CodeSymbolIndex.supports(language), source.utf8.count <= 2_000_000 else { return [:] }
        let patterns: [String]
        switch language {
        case .python:
            patterns = [
                #"(?m)^[ \t]*((?:self|cls)\.[A-Za-z_]\w*)[ \t]*=[ \t]*([A-Za-z_][\w.]*)[ \t]*\("#,
                #"(?m)^[ \t]*([A-Za-z_]\w*)[ \t]*=[ \t]*([A-Za-z_][\w.]*)[ \t]*\("#,
                #"(?m)^[ \t]*([A-Za-z_]\w*)[ \t]*:[ \t]*([A-Za-z_][\w.]*)[ \t]*(?:#.*)?$"#,
                #"(?:(?:self|cls)\.)?([A-Za-z_]\w*)[ \t]*:[ \t]*([A-Z][A-Za-z0-9_]*)"#
            ]
        case .javascript, .typescript:
            patterns = [
                #"(?:(this\.[A-Za-z_$][\w$]*)|([A-Za-z_$][\w$]*))\s*=\s*new\s+([A-Za-z_$][\w$]*)"#,
                #"(?:(?:public|private|protected|readonly|static|override|abstract|declare)\s+)*((?:this\.)?[A-Za-z_$][\w$]*)\s*[?!]?\s*:\s*([A-Z][A-Za-z0-9_]*)"#
            ]
        case .dart:
            patterns = [
                #"(?:(this\.[A-Za-z_]\w*)|([A-Za-z_]\w*))\s*=\s*(?:new\s+)?([A-Z][A-Za-z0-9_]*)\s*(?:<|\()"#,
                #"([A-Za-z_]\w*)\s*:\s*([A-Z][A-Za-z0-9_]*)"#,
                #"(?:final|late|const|var)?\s*([A-Z][A-Za-z0-9_]*)(?:<[^;\n]{0,80}>)?\s+([A-Za-z_]\w*)"#
            ]
        default:
            return [:]
        }
        var bound: [String: String] = [:]
        func add(_ qualifier: String, _ type: String) {
            let typeName = type.split(separator: ".").last.map(String.init) ?? type
            let rejected: Set<String> = ["if", "for", "while", "return", "const", "let", "var", "function", "class", "import", "export", "new", "await", "async", "public", "private", "protected", "readonly", "static", "get", "set", "final", "late"]
            guard let first = typeName.first, first.isUppercase, !qualifier.isEmpty, !rejected.contains(qualifier) else { return }
            let key = qualifier.split(separator: ".").map { $0.lowercased() }.joined(separator: ".")
            if let existing = bound[key], existing != typeName { bound[key] = ""; return }
            bound[key] = typeName
            if !key.contains(".") {
                for prefix in ["self.", "this."] where bound[prefix + key] == nil {
                    bound[prefix + key] = typeName
                }
            }
        }
        let range = NSRange(location: 0, length: source.utf16.count)
        for pattern in patterns {
            guard let expression = try? NSRegularExpression(pattern: pattern) else { continue }
            expression.enumerateMatches(in: source, range: range) { match, _, _ in
                guard let match else { return }
                let groups = (1..<match.numberOfRanges).compactMap { index -> String? in
                    let captured = match.range(at: index)
                    guard captured.location != NSNotFound else { return nil }
                    let value = substring(source, captured)
                    return value.isEmpty ? nil : value
                }
                guard var type = groups.last, var qualifier = groups.dropLast().first else { return }
                if language == .dart, let qualifierFirst = qualifier.first, qualifierFirst.isUppercase,
                   let typeFirst = type.first, !typeFirst.isUppercase {
                    swap(&qualifier, &type)
                }
                add(qualifier, type)
            }
        }
        return bound.filter { !$0.value.isEmpty }
    }

    static func moduleMatches(file: String, module: String) -> Bool {
        if file == module { return true }
        let fileBase = (file as NSString).deletingPathExtension
        let moduleBase = (module as NSString).deletingPathExtension
        if fileBase == module || fileBase == moduleBase { return true }
        if fileBase == module + "/index" || fileBase.hasSuffix("/" + module) || fileBase.hasSuffix("/" + moduleBase) || fileBase.hasSuffix("/" + module + "/index") { return true }
        if fileBase == module + "/__init__" || fileBase.hasSuffix("/" + module + "/__init__") { return true }
        return false
    }

    private static func collectScripts(_ source: String, filePath: String, add: (String, String) -> Void) {
        let from = try? NSRegularExpression(pattern: #"import\s+(?:type\s+)?([\s\S]*?)\s+from\s+['"]([^'"]+)['"]"#)
        let range = NSRange(location: 0, length: source.utf16.count)
        from?.enumerateMatches(in: source, range: range) { match, _, _ in
            guard let match, match.numberOfRanges > 2 else { return }
            let clause = substring(source, match.range(at: 1))
            let specifier = substring(source, match.range(at: 2))
            guard let module = relative(specifier, filePath: filePath) else { return }
            for name in scriptNames(clause) { add(name, module) }
        }
        let require = try? NSRegularExpression(pattern: #"(?:const|let|var)\s+(?:([A-Za-z_$][\w$]*)|\{([^}]+)\})\s*=\s*require\(\s*['"]([^'"]+)['"]\s*\)"#)
        require?.enumerateMatches(in: source, range: range) { match, _, _ in
            guard let match, let module = relative(substring(source, match.range(at: 3)), filePath: filePath) else { return }
            if match.range(at: 1).location != NSNotFound { add(substring(source, match.range(at: 1)), module) }
            if match.range(at: 2).location != NSNotFound {
                for name in aliasNames(substring(source, match.range(at: 2))) { add(name, module) }
            }
        }
    }

    private static func collectPython(_ source: String, filePath: String, add: (String, String) -> Void) {
        let expression = try? NSRegularExpression(pattern: #"(?m)^\s*(?:import\s+([A-Za-z_][\w.]*)(?:\s+as\s+([A-Za-z_]\w*))?|from\s+(\.*)([A-Za-z_][\w.]*)?\s+import\s+([^#\n]+))"#, options: [])
        let range = NSRange(location: 0, length: source.utf16.count)
        expression?.enumerateMatches(in: source, range: range) { match, _, _ in
            guard let match else { return }
            if match.range(at: 1).location != NSNotFound {
                let moduleName = substring(source, match.range(at: 1))
                let alias = match.range(at: 2).location == NSNotFound ? moduleName.split(separator: ".").first.map(String.init) ?? moduleName : substring(source, match.range(at: 2))
                add(alias, moduleName.replacingOccurrences(of: ".", with: "/"))
                return
            }
            let dots = match.range(at: 3).location == NSNotFound ? "" : substring(source, match.range(at: 3))
            let module = match.range(at: 4).location == NSNotFound ? "" : substring(source, match.range(at: 4))
            let names = substring(source, match.range(at: 5)).replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
            if module.isEmpty {
                for symbol in importedSymbols(names) {
                    add(symbol.binding, pythonRelative(dots: max(dots.count, 1), module: symbol.source, filePath: filePath))
                }
                return
            }
            let resolved = dots.isEmpty
                ? module.replacingOccurrences(of: ".", with: "/")
                : pythonRelative(dots: dots.count, module: module, filePath: filePath)
            for symbol in importedSymbols(names) { add(symbol.binding, resolved) }
        }
    }

    static func libraries(in source: String, language: CodeLanguage, filePath: String) -> [String] {
        guard language == .dart, source.utf8.count <= 2_000_000 else { return [] }
        let expression = try? NSRegularExpression(pattern: #"import\s+['"]([^'"]+)['"](?:\s+as\s+([A-Za-z_]\w*))?(?:\s+show\s+([^;]+))?;"#)
        let range = NSRange(location: 0, length: source.utf16.count)
        var modules: [String] = []
        expression?.enumerateMatches(in: source, range: range) { match, _, _ in
            guard let match, match.range(at: 2).location == NSNotFound, match.range(at: 3).location == NSNotFound,
                  let module = dartModule(substring(source, match.range(at: 1)), filePath: filePath) else { return }
            modules.append(module)
        }
        return modules
    }

    private static func collectDart(_ source: String, filePath: String, add: (String, String) -> Void) {
        let expression = try? NSRegularExpression(pattern: #"import\s+['"]([^'"]+)['"](?:\s+as\s+([A-Za-z_]\w*))?(?:\s+show\s+([^;]+))?"#)
        let range = NSRange(location: 0, length: source.utf16.count)
        expression?.enumerateMatches(in: source, range: range) { match, _, _ in
            guard let match else { return }
            let specifier = substring(source, match.range(at: 1))
            guard let module = dartModule(specifier, filePath: filePath) else { return }
            if match.range(at: 2).location != NSNotFound { add(substring(source, match.range(at: 2)), module) }
            if match.range(at: 3).location != NSNotFound {
                for name in aliasNames(substring(source, match.range(at: 3))) { add(name, module) }
            }
        }
    }

    private static func scriptNames(_ clause: String) -> [String] {
        var names: [String] = []
        let cleaned = clause.replacingOccurrences(of: "\n", with: " ")
        if let star = cleaned.range(of: #"\*\s+as\s+([A-Za-z_$][\w$]*)"#, options: .regularExpression) {
            let written = String(cleaned[star])
            if let name = written.split(separator: " ").last { names.append(String(name)) }
        }
        if let braceStart = cleaned.firstIndex(of: "{"), let braceEnd = cleaned.lastIndex(of: "}") {
            names.append(contentsOf: aliasNames(String(cleaned[cleaned.index(after: braceStart)..<braceEnd])))
            let before = cleaned[..<braceStart].replacingOccurrences(of: ",", with: " ")
            if let name = before.split(separator: " ").last, name != "type" { names.append(String(name)) }
        } else if let name = cleaned.split(separator: " ").last, name != "type", !name.hasPrefix("*") {
            names.append(String(name))
        }
        return names
    }

    private static func aliasNames(_ list: String) -> [String] {
        importedSymbols(list).map(\.binding)
    }

    private static func importedSymbols(_ list: String) -> [(binding: String, source: String)] {
        list.split(separator: ",").compactMap { item in
            let words = item.split { $0 == " " || $0 == "\n" || $0 == "\t" }.map(String.init).filter { $0 != "type" }
            guard let name = words.last, name != "as" else { return nil }
            let origin = words.contains("as") ? words.first ?? name : name
            return (name, origin)
        }
    }

    private static func relative(_ specifier: String, filePath: String) -> String? {
        if specifier.hasPrefix(".") { return join(specifier, filePath: filePath) }
        guard specifier.contains("/"), !specifier.hasPrefix("@") else { return nil }
        return specifier
    }

    private static func dartModule(_ specifier: String, filePath: String) -> String? {
        if specifier.hasPrefix(".") { return join(specifier, filePath: filePath) }
        guard specifier.hasPrefix("package:") else { return nil }
        let parts = specifier.dropFirst("package:".count).split(separator: "/").map(String.init)
        guard parts.count >= 2 else { return nil }
        return parts.dropFirst().joined(separator: "/")
    }

    private static func join(_ specifier: String, filePath: String) -> String {
        var parts = (filePath as NSString).deletingLastPathComponent.split(separator: "/").map(String.init)
        for piece in specifier.split(separator: "/") {
            if piece == "." { continue }
            if piece == ".." { if !parts.isEmpty { parts.removeLast() }; continue }
            parts.append(String(piece))
        }
        return parts.joined(separator: "/")
    }

    private static func pythonRelative(dots: Int, module: String, filePath: String) -> String {
        var parts = (filePath as NSString).deletingLastPathComponent.split(separator: "/").map(String.init)
        for _ in 0..<max(0, dots - 1) { if !parts.isEmpty { parts.removeLast() } }
        if !module.isEmpty { parts.append(contentsOf: module.split(separator: ".").map(String.init)) }
        return parts.joined(separator: "/")
    }

    private static func substring(_ source: String, _ range: NSRange) -> String {
        guard range.location != NSNotFound, let span = Range(range, in: source) else { return "" }
        return String(source[span])
    }

    private static func normalize(_ value: String) -> String {
        String(value.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
    }
}
