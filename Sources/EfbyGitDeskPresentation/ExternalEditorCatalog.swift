import AppKit
import EfbyGitDeskDomain

public struct ExternalEditor: Identifiable, Sendable, Equatable {
    public let bundleIdentifier: String
    public let displayName: String
    public let applicationURL: URL

    public var id: String { bundleIdentifier }
}

enum ExternalEditorCatalog {
    /// Orden de preferencia en menús; solo se muestran las apps presentes en el sistema.
    private static let knownEditors: [(fallbackName: String, bundleIdentifier: String)] = [
        ("Cursor", "com.todesktop.230313mzl4w4u92"),
        ("Cursor", "com.cursor.Cursor"),
        ("Visual Studio Code", "com.microsoft.VSCode"),
        ("Visual Studio Code - Insiders", "com.microsoft.VSCodeInsiders"),
        ("Zed", "dev.zed.Zed"),
        ("Nova", "com.panic.Nova"),
        ("Sublime Text", "com.sublimetext.4"),
        ("BBEdit", "com.barebones.bbedit"),
        ("TextMate", "com.macromates.TextMate"),
        ("Xcode", "com.apple.dt.Xcode"),
        ("Fleet", "com.jetbrains.fleet"),
        ("IntelliJ IDEA", "com.jetbrains.intellij"),
        ("WebStorm", "com.jetbrains.WebStorm"),
        ("PyCharm", "com.jetbrains.pycharm"),
        ("Android Studio", "com.google.android.studio"),
    ]

    static func installedCursor() -> ExternalEditor? {
        for bundleIdentifier in ["com.todesktop.230313mzl4w4u92", "com.cursor.Cursor"] {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else { continue }
            let localized = FileManager.default.displayName(atPath: url.path)
            let name = localized.isEmpty ? "Cursor" : localized
            return ExternalEditor(bundleIdentifier: bundleIdentifier, displayName: name, applicationURL: url)
        }
        return nil
    }

    static func installedEditors() -> [ExternalEditor] {
        var seen = Set<String>()
        var editors: [ExternalEditor] = []
        for candidate in knownEditors {
            guard !seen.contains(candidate.bundleIdentifier),
                  let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: candidate.bundleIdentifier) else { continue }
            seen.insert(candidate.bundleIdentifier)
            let localized = FileManager.default.displayName(atPath: url.path)
            let name = localized.isEmpty ? candidate.fallbackName : localized
            editors.append(ExternalEditor(bundleIdentifier: candidate.bundleIdentifier, displayName: name, applicationURL: url))
        }
        return editors
    }

    static func open(path: String, with editor: ExternalEditor) async throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw DeskError("La carpeta del proyecto ya no está disponible en disco.")
        }
        let folder = URL(fileURLWithPath: path, isDirectory: true)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            NSWorkspace.shared.open([folder], withApplicationAt: editor.applicationURL, configuration: configuration) { _, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }
    }
}
