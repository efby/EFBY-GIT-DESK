import AppKit
import Foundation
import EfbyGitDeskDomain

enum CursorComparisonPrompt {
    static func make(pair: ComparisonPair,
                     baseMessage: String,
                     targetMessage: String,
                     repositoryName: String,
                     changedFilePaths: [String] = []) -> String {
        let a = String(pair.base.prefix(8))
        let b = String(pair.target.prefix(8))
        var lines = [
            "Comparación A→B en \(repositoryName) (A más antiguo):",
            "A \(a) — \(singleLine(baseMessage))",
            "B \(b) — \(singleLine(targetMessage))",
            "",
            "Explica qué cambió entre A y B, riesgos y qué revisar.",
        ]
        let paths = changedFilePaths.map(\.self).filter { !$0.isEmpty }.sorted()
        if paths.count == 1 {
            lines.append("Archivo modificado: \(paths[0])")
        } else if paths.count > 1 {
            lines.append("Archivos modificados (\(paths.count)):")
            lines.append(contentsOf: paths.map { "- \($0)" })
        }
        return lines.joined(separator: "\n")
    }

    private static func singleLine(_ message: String) -> String {
        let line = message.split(whereSeparator: \.isNewline).first.map(String.init) ?? message
        if line.count <= 120 { return line }
        return String(line.prefix(117)) + "..."
    }
}

enum CursorPromptLink {
    private static let maxURLLength = 10_000

    static var isInstalled: Bool { ExternalEditorCatalog.installedCursor() != nil }

    @discardableResult
    static func openRepositoryAndPrompt(repositoryPath: String, prompt: String) async throws -> Bool {
        guard let cursor = ExternalEditorCatalog.installedCursor() else {
            throw DeskError("Cursor no está instalado en este Mac.")
        }
        copyToClipboard(prompt)
        try await ExternalEditorCatalog.open(path: repositoryPath, with: cursor)
        try await Task.sleep(for: .milliseconds(1_200))
        return deliverPromptDeeplink(prompt)
    }

    static func copyToClipboard(_ prompt: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt, forType: .string)
    }

    @discardableResult
    static func deliverPromptDeeplink(_ prompt: String) -> Bool {
        if let url = promptURL(for: prompt, web: false), NSWorkspace.shared.open(url) { return true }
        if let url = promptURL(for: prompt, web: true), NSWorkspace.shared.open(url) { return true }
        return false
    }

    static func promptURL(for prompt: String, web: Bool = false) -> URL? {
        var text = prompt
        let prefix = web ? "https://cursor.com/link/prompt?text=" : "cursor://anysphere.cursor-deeplink/prompt?text="
        while !text.isEmpty {
            let candidate = prefix + percentEncodeQueryValue(text)
            if candidate.count <= maxURLLength, let url = URL(string: candidate) { return url }
            text = shorten(text)
        }
        return nil
    }

    private static func percentEncodeQueryValue(_ value: String) -> String {
        value.utf8.map { byte -> String in
            switch byte {
            case 0x30...0x39, 0x41...0x5A, 0x61...0x7A, 0x2D, 0x2E, 0x5F, 0x7E:
                return String(UnicodeScalar(byte))
            case 0x20:
                return "%20"
            default:
                return String(format: "%%%02X", byte)
            }
        }.joined()
    }

    private static func shorten(_ prompt: String) -> String {
        String(prompt.prefix(max(400, prompt.count - 1_000)))
    }
}
