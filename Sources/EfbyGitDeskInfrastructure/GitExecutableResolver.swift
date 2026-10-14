import Foundation
import EfbyGitDeskDomain

/// Finds a Git executable by validating `git --version` (≥ 2.40). User installs are tried before Apple-provided paths.
public struct GitExecutableResolver: Sendable {
    private let runner = ProcessRunner()
    public init() {}

    public static func candidates(path: String, home: String) -> [String] {
        let directories = path.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
            + [home + "/.local/bin", home + "/bin", home + "/.nix-profile/bin",
               home + "/homebrew/bin", home + "/miniforge3/bin", "/opt/homebrew/bin", "/usr/local/bin", "/usr/local/git/bin", "/opt/local/bin"]
        var seen = Set<String>()
        return directories.filter { $0.hasPrefix("/") }.map { URL(fileURLWithPath: $0).appendingPathComponent("git").path }
            .filter { seen.insert($0).inserted }
    }

    /// Apple/Xcode/CLT locations are used only after other candidates fail `git --version`.
    public static func isAppleProvidedGit(_ path: String) -> Bool {
        let canonical = URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path
        return canonical == "/usr/bin/git" || canonical.contains("/Library/Developer/")
            || canonical.contains(".app/Contents/Developer/")
    }

    private static func orderedCandidates(path: String, home: String) -> [String] {
        let all = candidates(path: path, home: home)
        return all.filter { !isAppleProvidedGit($0) } + all.filter { isAppleProvidedGit($0) }
    }

    public func resolve(preferred: String? = nil,
                        path: String = ProcessInfo.processInfo.environment["PATH"] ?? "",
                        home: String = FileManager.default.homeDirectoryForCurrentUser.path) async throws -> String {
        if let preferred, !preferred.isEmpty {
            guard preferred.hasPrefix("/"), FileManager.default.isExecutableFile(atPath: preferred) else {
                throw DeskError("Selecciona un ejecutable Git con ruta absoluta y permisos de ejecución para tu cuenta.")
            }
            _ = try await version(at: preferred)
            return URL(fileURLWithPath: preferred).standardizedFileURL.path
        }
        for candidate in Self.orderedCandidates(path: path, home: home) {
            try Task.checkCancellation()
            guard FileManager.default.isExecutableFile(atPath: candidate) else { continue }
            do {
                _ = try await version(at: candidate)
                return candidate
            } catch is CancellationError { throw CancellationError() }
            catch { continue }
        }
        throw DeskError("No encontré un Git compatible en tu cuenta. En Ajustes → Git selecciona el ejecutable que usas en Terminal (command -v git). Se requiere Git 2.40 o posterior; no se instala ni modifica Git automáticamente.")
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
