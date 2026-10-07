import Foundation

public enum CodeLanguage: String, CaseIterable, Identifiable, Sendable {
    case automatic = "Automático", plain = "Texto plano", python = "Python", javascript = "JavaScript", typescript = "TypeScript"
    case swift = "Swift", java = "Java", kotlin = "Kotlin", c = "C / C++", csharp = "C#", go = "Go", rust = "Rust"
    case ruby = "Ruby", shell = "Shell", sql = "SQL", json = "JSON", yaml = "YAML / TOML", html = "HTML / XML", css = "CSS", markdown = "Markdown"
    public var id: Self { self }
    public static func detect(path: String) -> Self {
        let url = URL(fileURLWithPath: path)
        switch url.pathExtension.lowercased() {
        case "py", "pyi", "pyw": return .python
        case "js", "jsx", "mjs", "cjs": return .javascript
        case "ts", "tsx", "mts", "cts": return .typescript
        case "swift": return .swift
        case "java": return .java
        case "kt", "kts": return .kotlin
        case "c", "h", "cc", "cpp", "hpp", "cxx": return .c
        case "cs": return .csharp
        case "go": return .go
        case "rs": return .rust
        case "rb": return .ruby
        case "sh", "bash", "zsh", "fish": return .shell
        case "sql": return .sql
        case "json", "jsonc": return .json
        case "yml", "yaml", "toml": return .yaml
        case "html", "htm", "xml", "svg", "vue": return .html
        case "css", "scss", "sass", "less": return .css
        case "md", "markdown": return .markdown
        default:
            return ["Dockerfile", "Makefile", ".bashrc", ".zshrc"].contains(url.lastPathComponent) ? .shell : .plain
        }
    }
    var keywords: Set<String> {
        let words: String
        switch self {
        case .python: words = "and as assert async await break class continue def del elif else except finally for from global if import in is lambda nonlocal not or pass raise return try while with yield True False None"
        case .javascript, .typescript: words = "async await break case catch class const continue debugger default delete do else export extends finally for from function if import in instanceof let new of return static super switch this throw try typeof var void while with yield true false null undefined interface type enum implements declare namespace public private protected readonly abstract as satisfies keyof infer unknown never any string number boolean"
        case .swift: words = "actor as associatedtype async await break case catch class continue default defer deinit do else enum extension fallthrough fileprivate for func guard if import in init inout internal is let nonisolated open operator private protocol public repeat rethrows return self some static struct subscript super switch throws throw try typealias var where while true false nil"
        case .sql: words = "select from where join inner left right outer on as insert into values update set delete create alter drop table index view distinct group by having order asc desc limit offset union all null not and or exists case when then else end primary key foreign references constraint count sum max min avg begin commit rollback"
        case .shell: words = "if then else elif fi for in do done while until case esac function return export local readonly break continue source"
        case .ruby: words = "def end class module if elsif else unless while until for in do begin rescue ensure return yield require include attr_reader true false nil"
        case .rust: words = "as async await break const continue crate dyn else enum extern false fn for if impl in let loop match mod move mut pub ref return self Self static struct super trait true type unsafe use where while"
        case .go: words = "break case chan const continue default defer else fallthrough for func go goto if import interface map package range return select struct switch type var true false nil"
        case .json, .yaml: words = "true false null yes no on off"
        case .java, .kotlin, .c, .csharp: words = "abstract as async await boolean bool break byte case catch char class const continue default do double else enum extends false final finally float for foreach fun if implements import int interface internal is long namespace native new null object override package private protected public return sealed short static string struct super switch synchronized this throw throws true try type typeof using val var virtual void volatile when while"
        default: words = ""
        }
        return Set(words.split(separator: " ").map(String.init))
    }
    var hashComments: Bool { [.python, .ruby, .shell, .yaml].contains(self) }
    var slashComments: Bool { [.javascript, .typescript, .swift, .java, .kotlin, .c, .csharp, .go, .rust, .json, .css].contains(self) }
}
