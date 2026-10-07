import Foundation
import EfbyGitDeskDomain

/// Finds an existing user installation without invoking Apple's developer-tool launchers.
public struct GitExecutableResolver: Sendable {
    private let runner = ProcessRunner()
    public init() {}

    public static func candidates(path: String, home: String) -> [String] {
        let directories = path.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
            + [home + "/.local/bin", home + "/bin", home + "/.nix-profile/bin",
               home + "/homebrew/bin", "/opt/homebrew/bin", "/usr/local/bin", "/usr/local/git/bin", "/opt/local/bin"]
        var seen = Set<String>()
        return directories.filter { $0.hasPrefix("/") }.map { URL(fileURLWithPath: $0).appendingPathComponent("git").path }
            .filter { seen.insert($0).inserted && !isDeveloperTool($0) }
    }

    public static func isDeveloperTool(_ path: String) -> Bool {
        let canonical = URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path
        return canonical == "/usr/bin/git" || canonical.hasPrefix("/Library/Developer/")
            || canonical.contains(".app/Contents/Developer/")
    }

    public func resolve(preferred: String? = nil,
                        path: String = ProcessInfo.processInfo.environment["PATH"] ?? "",
                        home: String = FileManager.default.homeDirectoryForCurrentUser.path) async throws -> String {
        if let preferred, !preferred.isEmpty {
            guard preferred.hasPrefix("/"), !Self.isDeveloperTool(preferred),
                  FileManager.default.isExecutableFile(atPath: preferred) else {
                throw DeskError("Selecciona un Git independiente y accesible para tu cuenta. El Git de Xcode o de las herramientas de Apple no se utiliza.")
            }
            _ = try await version(at: preferred)
            return URL(fileURLWithPath: preferred).standardizedFileURL.path
        }
        for candidate in Self.candidates(path: path, home: home) {
            try Task.checkCancellation()
            guard FileManager.default.isExecutableFile(atPath: candidate), !Self.isDeveloperTool(candidate) else { continue }
            do {
                _ = try await version(at: candidate)
                return candidate
            } catch is CancellationError { throw CancellationError() }
            catch { continue }
        }
        throw DeskError("No encontré un Git independiente compatible en tu cuenta. En Ajustes → Git selecciona el ejecutable que usas en Terminal (command -v git). No necesitas aceptar la licencia de Xcode ni permisos de administrador. Se requiere Git 2.40 o posterior; no se instala ni modifica Git automáticamente.")
    }

    public func version(at path: String) async throws -> String {
        let result = try await runner.run(executable: path, arguments: ["--version"], directory: NSTemporaryDirectory(),
                                          environment: ["GIT_TERMINAL_PROMPT": "0"], limit: 16_384, timeout: 5)
        guard result.status == 0, !result.truncated else {
            throw DeskError("No se pudo ejecutar ese Git con los permisos de tu cuenta. Selecciona otra instalación en Ajustes → Git.")
        }
        let value = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let fields = value.split(separator: " ")
        guard fields.count >= 3, fields[0] == "git", fields[1] == "version" else {
            throw DeskError("El archivo seleccionado no respondió como Git. Selecciona el ejecutable git que usas en Terminal.")
        }
        let numbers = fields[2].split(separator: ".")
        guard numbers.count >= 2, let major = Int(numbers[0]), let minor = Int(numbers[1]),
              major > 2 || (major == 2 && minor >= 40) else {
            throw DeskError("EFBY Git Desk requiere Git 2.40 o posterior. Elige otra instalación disponible para tu cuenta.")
        }
        return value
    }
}
