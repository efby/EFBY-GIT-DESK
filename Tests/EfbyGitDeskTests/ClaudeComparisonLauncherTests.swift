import Foundation
import Testing
@testable import EfbyGitDeskPresentation

@MainActor @Suite struct ClaudeComparisonLauncherTests {
    @Test func codeLinkEncodesPromptAndAbsoluteFolderWithoutChangingTheirText() throws {
        let prompt = "Explica A→B: archivo & riesgo?\nCambio: café #1"
        let folder = "/Users/raúl/Proyecto & pruebas/100%"
        let url = try #require(ClaudeComparisonLauncher.promptURL(for: prompt, repositoryPath: folder))
        #expect(url.scheme == "claude")
        #expect(url.host == "code")
        #expect(url.path == "/new")
        #expect(url.absoluteString.contains("folder=%2FUsers%2Fra%C3%BAl%2FProyecto%20%26%20pruebas%2F100%25"))
        let values = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(values.first(where: { $0.name == "q" })?.value == prompt)
        #expect(values.first(where: { $0.name == "folder" })?.value == folder)
    }

    @Test func oversizedPromptUsesFolderOnlyFallback() throws {
        let folder = "/Users/test/project"
        #expect(ClaudeComparisonLauncher.promptURL(for: String(repeating: "a", count: 12_001),
                                                   repositoryPath: folder) == nil)
        let url = try #require(ClaudeComparisonLauncher.folderURL(repositoryPath: folder))
        let values = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(values.map(\.name) == ["folder"])
        #expect(values.first?.value == folder)
        #expect(url.absoluteString.utf8.count <= 16_000)
    }

    @Test func relativeOrNulFolderIsNeverLinked() {
        #expect(ClaudeComparisonLauncher.promptURL(for: "explica", repositoryPath: "relative/project") == nil)
        #expect(ClaudeComparisonLauncher.folderURL(repositoryPath: "/tmp/project\0other") == nil)
    }

    @Test func installationDetectionMatchesApplicationCatalog() {
        #expect(ClaudeComparisonLauncher.isInstalled == (ExternalEditorCatalog.installedClaude() != nil))
    }
}
