import Foundation
import Testing
@testable import EfbyGitDeskPresentation

@Suite struct ExternalEditorCatalogTests {
    @Test func installedEditorsHaveUniqueBundleIdentifiers() {
        let editors = ExternalEditorCatalog.installedEditors()
        #expect(Set(editors.map(\.bundleIdentifier)).count == editors.count)
        for editor in editors {
            #expect(FileManager.default.fileExists(atPath: editor.applicationURL.path))
        }
    }

    @Test func installedClaudeAppearsInOpenInEditorMenu() {
        guard let claude = ExternalEditorCatalog.installedClaude() else { return }
        #expect(claude.bundleIdentifier == "com.anthropic.claudefordesktop")
        #expect(ExternalEditorCatalog.installedEditors().contains(claude))
    }
}
