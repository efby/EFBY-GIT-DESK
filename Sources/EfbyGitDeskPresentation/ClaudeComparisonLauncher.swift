import AppKit
import Foundation
import EfbyGitDeskDomain

/// Opens a Claude Code session in Claude Desktop. Claude asks the user to confirm
/// the local folder and leaves the prompt in the composer for review and sending.
enum ClaudeComparisonLauncher {
    private static let maxPromptBytes = 12_000 // Claude truncates q near 14,000 characters.
    private static let maxURLBytes = 16_000
    private static let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    @MainActor static var isInstalled: Bool { ExternalEditorCatalog.installedClaude() != nil }

    /// `true` means the prompt was passed to Claude's composer. If a link would
    /// exceed the conservative limit, `false` means the full prompt is on the
    /// clipboard and Claude was opened with the folder only.
    @discardableResult
    @MainActor static func openRepositoryAndPrompt(repositoryPath: String, prompt: String) async throws -> Bool {
        guard let claude = ExternalEditorCatalog.installedClaude() else {
            throw DeskError("Claude no está instalado en este Mac.")
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: repositoryPath, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw DeskError("La carpeta del proyecto ya no está disponible en disco.")
        }
        try Task.checkCancellation()
        if let link = promptURL(for: prompt, repositoryPath: repositoryPath) {
            do {
                try await ExternalEditorCatalog.openClaudeLink(link, with: claude)
                return true
            } catch is CancellationError { throw CancellationError() }
            catch { /* Try the folder-only link and leave the prompt ready to paste. */ }
        }
        NSPasteboard.general.clearContents()
        guard NSPasteboard.general.setString(prompt, forType: .string) else {
            throw DeskError("No se pudo copiar el mensaje de comparación al portapapeles.")
        }
        if let link = folderURL(repositoryPath: repositoryPath) {
            do {
                try await ExternalEditorCatalog.openClaudeLink(link, with: claude)
                return false
            } catch is CancellationError { throw CancellationError() }
            catch { throw DeskError("Claude no pudo abrir una sesión de código con esta carpeta. El mensaje completo quedó copiado para pegarlo cuando abras Claude.") }
        }
        throw DeskError("Claude no pudo abrir una sesión de código con esta carpeta. El mensaje completo quedó copiado para pegarlo cuando abras Claude.")
    }

    static func promptURL(for prompt: String, repositoryPath: String) -> URL? {
        guard !prompt.isEmpty, prompt.utf8.count <= maxPromptBytes else { return nil }
        return codeSessionURL(repositoryPath: repositoryPath, prompt: prompt)
    }

    static func folderURL(repositoryPath: String) -> URL? {
        codeSessionURL(repositoryPath: repositoryPath, prompt: nil)
    }

    private static func codeSessionURL(repositoryPath: String, prompt: String?) -> URL? {
        guard repositoryPath.hasPrefix("/"), !repositoryPath.contains("\0") else { return nil }
        var components = URLComponents()
        components.scheme = "claude"
        components.host = "code"
        components.path = "/new"
        guard let encodedFolder = encodeQueryValue(repositoryPath) else { return nil }
        let folder = "folder=" + encodedFolder
        if let prompt {
            guard let encodedPrompt = encodeQueryValue(prompt) else { return nil }
            components.percentEncodedQuery = "q=" + encodedPrompt + "&" + folder
        } else {
            components.percentEncodedQuery = folder
        }
        guard let url = components.url, url.absoluteString.utf8.count <= maxURLBytes else { return nil }
        return url
    }

    private static func encodeQueryValue(_ value: String) -> String? {
        value.addingPercentEncoding(withAllowedCharacters: unreserved)
    }
}
