import Foundation
import EfbyGitDeskApplication
import EfbyGitDeskDomain

public actor GitAdapter: GitRepositoryPort {
    private let executable: String
    private let runner = ProcessRunner()
    private let vault: KeychainVault
    private let helper: String
    private let allowLocalRemotes: Bool
    public init(executable: String, vault: KeychainVault, credentialHelper: String,
                allowLocalRemotes: Bool = false) {
        self.executable = executable; self.vault = vault
        self.helper = credentialHelper; self.allowLocalRemotes = allowLocalRemotes
    }
    public func version() async throws -> String {
        let result = try await runner.run(executable: executable, arguments: ["--version"], directory: NSTemporaryDirectory(), timeout: 10)
        let fields = result.text.split(separator: " ")
        guard result.status == 0, fields.count >= 3, fields[0] == "git", fields[1] == "version" else {
            throw DeskError("El ejecutable encontrado no es Git.")
        }
        let numbers = fields[2].split(separator: ".").compactMap { Int($0) }
        guard numbers.count >= 2, numbers[0] > 2 || (numbers[0] == 2 && numbers[1] >= 40) else {
            throw DeskError("EfbyGitDesk requiere Git 2.40 o posterior. Instálalo antes de continuar.")
        }
        return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private func run(_ arguments: [String], directory: String, trusted: Bool = false,
                     input: Data? = nil, environment: [String: String] = [:],
                     limit: Int = 16 * 1024 * 1024, allowFailure: Bool = false, timeout: TimeInterval = 90) async throws -> ProcessResult {
        try Task.checkCancellation()
        let base = ["--no-replace-objects", "-c", "core.pager=cat", "-c", "color.ui=false",
                    "-c", "core.fsmonitor=false", "-c", "core.untrackedCache=false"]
        let safe = trusted ? [] : ["-c", "core.hooksPath=/dev/null", "-c", "core.attributesFile=/dev/null"]
        var env = ["GIT_TERMINAL_PROMPT": "0", "GIT_NO_LAZY_FETCH": "1",
                   "GIT_OPTIONAL_LOCKS": "0", "GIT_PAGER": "cat", "GIT_EDITOR": "true",
                   "GIT_LITERAL_PATHSPECS": "1", "LC_ALL": "en_US.UTF-8"]
        if !trusted { env["GIT_CONFIG_NOSYSTEM"] = "1"; env["GIT_CONFIG_GLOBAL"] = "/dev/null" }
        environment.forEach { env[$0] = $1 }
        let result = try await runner.run(executable: executable, arguments: base + safe + arguments,
                                          directory: directory, input: input, environment: env, limit: limit, timeout: timeout)
        if result.status != 0 && !allowFailure {
            var text = String(decoding: result.error, as: UTF8.self)
            text = text.replacingOccurrences(of: #"https?://[^/\s@]+@"#, with: "https://[credencial]@", options: .regularExpression)
            throw DeskError(text.isEmpty ? "Git no pudo completar la operación." : String(text.prefix(2_000)))
        }
        return result
    }
    private func complete(_ result: ProcessResult) throws -> Data {
        guard !result.truncated else { throw DeskError("El resultado supera el límite de 16 MB. El inventario no se presenta como completo.") }
        return result.output
    }
    public func discover(path: String) async throws -> Repository {
        let canonical = URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path
        let bare = try await run(["rev-parse", "--is-bare-repository"], directory: canonical)
        guard bare.text.trimmingCharacters(in: .whitespacesAndNewlines) == "false" else { throw DeskError("Los repositorios bare no tienen área de trabajo compatible con este MVP.") }
        let root = try await run(["rev-parse", "--show-toplevel"], directory: canonical).text.trimmingCharacters(in: .whitespacesAndNewlines)
        let git = try await run(["rev-parse", "--absolute-git-dir"], directory: root).text.trimmingCharacters(in: .whitespacesAndNewlines)
        let common = try await run(["rev-parse", "--path-format=absolute", "--git-common-dir"], directory: root).text.trimmingCharacters(in: .whitespacesAndNewlines)
        let sparse = try await run(["config", "--bool", "core.sparseCheckout"], directory: root, allowFailure: true)
        guard sparse.text.trimmingCharacters(in: .whitespacesAndNewlines) != "true" else {
            throw DeskError("Se detectó sparse checkout. Este MVP conserva el repositorio y no lo abre para edición.")
        }
        let shallow = try await run(["rev-parse", "--is-shallow-repository"], directory: root).text.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
        let partial = try await run(["config", "--get", "extensions.partialClone"], directory: root, allowFailure: true).status == 0
        let superproject = try await run(["rev-parse", "--show-superproject-working-tree"], directory: root).text.trimmingCharacters(in: .whitespacesAndNewlines)
        let reason = shallow ? "Clon shallow: historial incompleto; solo inspección." : (partial ? "Clon parcial: no se descargarán objetos implícitamente; solo inspección." : (!superproject.isEmpty ? "Submódulo: solo inspección en este MVP." : nil))
        return Repository(path: URL(fileURLWithPath: root).resolvingSymlinksInPath().path,
                          gitDirectory: URL(fileURLWithPath: git).resolvingSymlinksInPath().path,
                          commonDirectory: URL(fileURLWithPath: common).resolvingSymlinksInPath().path,
                          name: URL(fileURLWithPath: root).lastPathComponent, inspectionReason: reason, identity: try directoryIdentity(common))
    }
    private func directoryIdentity(_ path: String) throws -> String {
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        guard let device = attributes[.systemNumber] as? NSNumber, let inode = attributes[.systemFileNumber] as? NSNumber else {
            throw DeskError("No se pudo verificar la identidad del directorio Git.")
        }
        return "\(device.uint64Value):\(inode.uint64Value)"
    }
    public func snapshot(_ repository: Repository) async throws -> RepositorySnapshot {
        if !repository.trusted || repository.inspectionReason != nil || repository.linkedWorktree {
            let head = try await run(["rev-parse", "--verify", "HEAD"], directory: repository.path, allowFailure: true)
            let branch = try await run(["symbolic-ref", "--quiet", "--short", "HEAD"], directory: repository.path, allowFailure: true)
            return RepositorySnapshot(head: head.status == 0 ? head.text.trimmingCharacters(in: .whitespacesAndNewlines) : "",
                                      branch: branch.text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        guard repository.identity != nil, try directoryIdentity(repository.commonDirectory) == repository.identity else {
            throw DeskError("El directorio Git cambió. Vuelve a abrir y revisar la confianza del repositorio.")
        }
        let result = try await run(["status", "--porcelain=v2", "-z", "--branch"], directory: repository.path, trusted: true)
        return GitParsers.status(try complete(result))
    }
    public func branches(_ repository: Repository) async throws -> [Branch] {
        let result = try await run(["for-each-ref", "--format=%(refname)%00%(objectname)%00%(upstream:short)%00%(HEAD)",
                                    "refs/heads", "refs/remotes"], directory: repository.path)
        let text = String(decoding: try complete(result), as: UTF8.self)
        return text.split(separator: "\n").compactMap { line in
            let fields = line.split(separator: "\0", omittingEmptySubsequences: false)
            guard fields.count == 4 else { return nil }
            return Branch(reference: String(fields[0]), oid: String(fields[1]), upstream: String(fields[2]), current: fields[3] == "*")
        }
    }
    public func history(_ repository: Repository, tips: [String], offset: Int, search: String) async throws -> [Commit] {
        let tips = Array(Set(tips.filter(ComparisonPair.validOID))).sorted()
        guard !tips.isEmpty else { return [] }
        guard tips.count <= 2_000, offset >= 0 else { throw DeskError("Demasiadas referencias para esta consulta de historial.") }
        var arguments = ["log", "--topo-order", "--date=iso-strict", "--max-count=100", "--skip=\(offset)",
                         "--format=%H%x00%P%x00%s%x00%an%x00%aI%x00%D%x00"]
        if !search.isEmpty { arguments += ["--fixed-strings", "--regexp-ignore-case", "--grep=" + search] }
        arguments += tips + ["--"]
        return try GitParsers.history(complete(await run(arguments, directory: repository.path)))
    }
    public func changes(_ repository: Repository, context: DiffContext) async throws -> [FileChange] {
        if context == .staged || context == .working {
            try requireTrust(repository)
            let state = try await snapshot(repository)
            return state.files.filter { context == .staged ? $0.staged : $0.unstaged }
        }
        let args = try await diffArguments(repository, context: context, inventory: true)
        return try GitParsers.changes(complete(await run(args, directory: repository.path)))
    }
    public func diff(_ repository: Repository, context: DiffContext, file: FileChange) async throws -> String {
        guard let path = file.utf8Path else {
            return "La ruta conserva sus bytes originales. Este visor no representa texto para nombres no UTF-8."
        }
        if context == .working || context == .staged { try requireTrust(repository) }
        if context == .working && file.status == "?" {
            let url = URL(fileURLWithPath: repository.path).appendingPathComponent(path)
            let canonical = url.resolvingSymlinksInPath().path
            guard canonical.hasPrefix(repository.path + "/") else { return "Enlace simbólico o ruta fuera del repositorio; no se lee su destino." }
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard (attributes[.size] as? NSNumber)?.intValue ?? Int.max <= 2_000_000 else {
                return "Archivo sin seguimiento: supera el límite textual de 2 MB. Permanece en el inventario."
            }
            let bytes = try Data(contentsOf: url)
            guard !bytes.contains(0), let text = String(data: bytes, encoding: .utf8) else { return "Archivo binario o no UTF-8 sin seguimiento." }
            return text
        }
        var args = try await diffArguments(repository, context: context, inventory: false)
        args += [path]
        if let old = file.oldPath, let oldPath = String(data: old, encoding: .utf8) { args.append(oldPath) }
        let result = try await run(args, directory: repository.path, trusted: repository.trusted, limit: 2_000_000)
        let summary: String
        if result.text.contains("Binary files ") { summary = "Archivo binario: Git informa el cambio sin representación textual.\n\n" }
        else if result.text.contains("version https://git-lfs.github.com/spec/v1") { summary = "Puntero Git LFS: se comparan referencias; no se descarga el contenido.\n\n" }
        else if result.text.contains("Subproject commit") { summary = "Submódulo: cambio de referencia del repositorio anidado.\n\n" }
        else if result.text.contains("mode 120000") { summary = "Enlace simbólico: se compara el destino textual del enlace.\n\n" }
        else { summary = "" }
        return summary + result.text + (result.truncated ? "\n\n[Diff truncado a 2 MB; el archivo permanece en el inventario.]" : "")
    }
    private func diffArguments(_ repository: Repository, context: DiffContext, inventory: Bool) async throws -> [String] {
        var args = ["diff", "--no-ext-diff", "--no-textconv"]
        if inventory { args += ["--name-status", "-z", "--find-renames"] }
        else { args += ["--unified=3", "--find-renames"] }
        switch context {
        case .commits(let pair):
            try await verify(pair.base, repository: repository); try await verify(pair.target, repository: repository)
            args += [pair.base, pair.target]
        case .staged: args += ["--cached"]
        case .working: break
        case .commit(let oid, let parent):
            try await verify(oid, repository: repository)
            let parents = try await run(["show", "-s", "--format=%P", oid], directory: repository.path).text
                .trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ").map(String.init)
            if parents.isEmpty {
                let empty = try await run(["hash-object", "-t", "tree", "--stdin"], directory: repository.path, input: Data()).text.trimmingCharacters(in: .whitespacesAndNewlines)
                args += [empty, oid]
            } else {
                guard parents.indices.contains(parent) else { throw DeskError("Padre del commit no válido.") }
                args += [parents[parent], oid]
            }
        }
        return args + ["--"]
    }
    private func verify(_ oid: String, repository: Repository) async throws {
        guard ComparisonPair.validOID(oid) else { throw DeskError("OID no válido.") }
        _ = try await run(["cat-file", "-e", oid + "^{commit}"], directory: repository.path)
    }
    public func remotes(_ repository: Repository) async throws -> [String] {
        let result = try await run(["remote"], directory: repository.path)
        return result.text.split(separator: "\n").map(String.init)
    }
    public func remoteSupported(_ repository: Repository, remote: String) async -> Bool {
        do {
            _ = try await destination(repository, remote: remote, push: false)
            _ = try await destination(repository, remote: remote, push: true)
            return true
        } catch { return false }
    }
    public func message(_ repository: Repository, oid: String) async throws -> String {
        try await verify(oid, repository: repository)
        return try await run(["show", "-s", "--format=%B", oid], directory: repository.path).text
    }
    private func destination(_ repository: Repository, remote: String, push: Bool) async throws -> String {
        guard try await remotes(repository).contains(remote), !remote.hasPrefix("-") else { throw DeskError("Selecciona un remoto válido.") }
        var args = ["remote", "get-url"]
        if push { args.append("--push") }
        args += ["--all", remote]
        let values = try await run(args, directory: repository.path, trusted: true).text.split(separator: "\n").map(String.init)
        guard values.count == 1 else { throw DeskError("Hay varios destinos remotos; este MVP requiere un destino único.") }
        try validateRemote(values[0])
        return values[0]
    }
    public func validateRemote(_ value: String) throws {
        if allowLocalRemotes && value.hasPrefix("/") { return }
        if value.hasPrefix("git@bitbucket.org:"), !value.contains("\n"), !value.contains("\r"),
           !value.dropFirst(18).contains("@"), value.dropFirst(18).split(separator: "/").count == 2 { return }
        if let url = URL(string: value), url.scheme == "https", url.host == "bitbucket.org",
           url.port == nil, url.password == nil, url.user == nil || url.user == "x-bitbucket-api-token-auth",
           url.query == nil, url.fragment == nil, url.path.split(separator: "/").count == 2 { return }
        throw DeskError("La integración remota de este MVP admite URLs HTTPS/SSH de Bitbucket Cloud. El trabajo local sigue disponible.")
    }
    private func network(_ args: [String], repository: Repository, profile: ConnectionProfile?, timeout: TimeInterval = 90, environment: [String: String] = [:]) async throws -> ProcessResult {
        var arguments = ["-c", "http.followRedirects=false", "-c", "protocol.allow=never",
                         "-c", "protocol.https.allow=always", "-c", "protocol.ssh.allow=always"]
        if allowLocalRemotes { arguments += ["-c", "protocol.file.allow=always"] }
        var env = environment
        var credential: String?
        if let profile, args.contains(where: { URL(string: $0)?.scheme == "https" }) {
            guard FileManager.default.isExecutableFile(atPath: helper) else { throw DeskError("No se encontró el helper firmado de credenciales. Usa el paquete .app o transporte SSH heredado.") }
            credential = try await vault.operation(profile: profile)
            env["GIT_ASKPASS"] = helper; env["EFBY_CREDENTIAL_OPERATION"] = credential
            arguments += ["-c", "credential.helper="]
        }
        do {
            let result = try await run(arguments + args, directory: repository.path, trusted: true, environment: env, timeout: timeout)
            if let credential { try? await vault.delete(id: credential) }
            return result
        } catch {
            if let credential { try? await vault.delete(id: credential) }
            throw error
        }
    }
    private func requireTrust(_ repository: Repository) throws {
        guard repository.trusted else { throw DeskError("Esta acción requiere confiar en el repositorio.") }
    }
    private func mutable(_ repository: Repository) async throws {
        try requireTrust(repository)
        guard !repository.linkedWorktree else { throw DeskError("La edición de worktrees vinculados no está habilitada.") }
        let actual = try await discover(path: repository.path)
        guard actual.inspectionReason == nil else { throw DeskError(actual.inspectionReason!) }
        guard actual.gitDirectory == repository.gitDirectory, actual.commonDirectory == repository.commonDirectory, actual.identity == repository.identity else {
            throw DeskError("La identidad del repositorio cambió. Vuelve a abrirlo.")
        }
    }
    public func execute(_ action: GitAction, repository: Repository, profile: ConnectionProfile?) async throws -> String {
        try await mutable(repository)
        try Task.checkCancellation()
        let state = try await snapshot(repository)
        switch action {
        case .stage(let paths):
            return try await run(["add", "--pathspec-from-file=-", "--pathspec-file-nul"], directory: repository.path, trusted: true, input: pathInput(paths)).text
        case .unstage(let paths):
            let args = state.head.isEmpty ? ["rm", "--cached", "--pathspec-from-file=-", "--pathspec-file-nul"] :
                ["restore", "--staged", "--pathspec-from-file=-", "--pathspec-file-nul"]
            return try await run(args, directory: repository.path, trusted: true, input: pathInput(paths)).text
        case .commit(let message):
            guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, state.files.contains(where: \.staged) else {
                throw DeskError("Prepara archivos e ingresa un mensaje antes de crear el commit.")
            }
            guard !state.files.contains(where: \.conflict) else { throw DeskError("Resuelve los conflictos antes de crear el commit.") }
            return try await run(["commit", "--file=-"], directory: repository.path, trusted: true, input: Data(message.utf8)).text
        case .createBranch(let name):
            try await validateBranch(name, repository: repository)
            return try await run(["branch", "--", name], directory: repository.path, trusted: true).text
        case .checkout(let name):
            try await validateBranch(name, repository: repository)
            return try await run(["switch", "--", name], directory: repository.path, trusted: true).text
        case .deleteBranch(let name):
            try await validateBranch(name, repository: repository)
            return try await run(["branch", "-d", "--", name], directory: repository.path, trusted: true).text
        case .fetch(let remote):
            return try await fetch(repository, remote: remote, profile: profile).text
        case .pull(let remote):
            _ = try await destination(repository, remote: remote, push: false)
            guard !state.upstream.isEmpty else { throw DeskError("No hay upstream. Establécelo al publicar la rama.") }
            let tracking = try await run(["for-each-ref", "--format=%(upstream:remotename)", "refs/heads/" + state.branch], directory: repository.path).text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard tracking == remote else { throw DeskError("Selecciona el remoto del upstream: \(tracking).") }
            _ = try await fetch(repository, remote: remote, profile: profile)
            let current = try await snapshot(repository)
            guard current.head == state.head, current.branch == state.branch, current.upstream == state.upstream else {
                throw DeskError("La rama cambió durante fetch. Pull se detuvo antes de modificarla.")
            }
            return try await run(["merge", "--ff-only", "--no-edit", "--", state.upstream], directory: repository.path, trusted: true).text
        case .push(let remote, let branch, let setUpstream):
            try await validateBranch(branch, repository: repository)
            let url = try await destination(repository, remote: remote, push: true)
            guard ComparisonPair.validOID(state.head), state.branch == branch else { throw DeskError("Solo se publica la rama local activa con HEAD válido.") }
            let result = try await network(["push", "--porcelain", "--", url, state.head + ":refs/heads/" + branch], repository: repository, profile: profile)
            if setUpstream {
                _ = try await run(["config", "branch." + branch + ".remote", remote], directory: repository.path, trusted: true)
                _ = try await run(["config", "branch." + branch + ".merge", "refs/heads/" + branch], directory: repository.path, trusted: true)
            }
            return result.text
        }
    }
    private func fetch(_ repository: Repository, remote: String, profile: ConnectionProfile?) async throws -> ProcessResult {
        let url = try await destination(repository, remote: remote, push: false)
        let refspec = "+refs/heads/*:refs/remotes/" + remote + "/*"
        return try await network(["fetch", "--no-prune", "--no-prune-tags", "--no-recurse-submodules", "--", url, refspec], repository: repository, profile: profile)
    }
    private func pathInput(_ paths: [Data]) throws -> Data {
        guard !paths.isEmpty, paths.allSatisfy({ !$0.isEmpty && !$0.contains(0) && !$0.starts(with: Data("/".utf8)) }) else {
            throw DeskError("Selecciona rutas relativas válidas.")
        }
        var data = Data()
        for path in paths { data.append(path); data.append(0) }
        return data
    }
    private func validateBranch(_ name: String, repository: Repository) async throws {
        guard !name.isEmpty, !name.hasPrefix("-") else { throw DeskError("Nombre de rama no válido.") }
        _ = try await run(["check-ref-format", "--branch", name], directory: repository.path)
    }
    public func clone(source: String, destination: String, profile: ConnectionProfile?) async throws -> Repository {
        try validateRemote(source)
        let target = URL(fileURLWithPath: destination).standardizedFileURL.resolvingSymlinksInPath()
        guard !FileManager.default.fileExists(atPath: target.path) else {
            throw DeskError("El destino ya existe. Elige una carpeta nueva; no se sobrescriben archivos.")
        }
        let staging = FileManager.default.temporaryDirectory.appendingPathComponent("EfbyGitDeskClone-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: staging) }
        let context = Repository(path: staging.path, gitDirectory: "", commonDirectory: "", name: "clone", trusted: true)
        _ = try await network(["-c", "core.hooksPath=/dev/null", "clone", "--no-checkout", "--", source, target.path], repository: context, profile: profile,
                              environment: ["GIT_CEILING_DIRECTORIES": staging.deletingLastPathComponent().path])
        var repository = try await discover(path: target.path)
        repository.pendingCheckout = true
        return repository
    }
    public func materializeClone(_ repository: Repository) async throws {
        try await mutable(repository)
        let entries = try FileManager.default.contentsOfDirectory(atPath: repository.path)
        guard entries.allSatisfy({ $0 == ".git" }) else { throw DeskError("El clon contiene archivos nuevos. El checkout inicial se detuvo para conservarlos.") }
        let state = try await snapshot(repository)
        guard !state.head.isEmpty else { return }
        _ = try await run(["read-tree", "--reset", "-u", "HEAD"], directory: repository.path, trusted: true)
    }
    public func prepareAmend(_ repository: Repository, message: String, publish: Bool, remote: String,
                             profile: ConnectionProfile?) async throws -> AmendPlan {
        try await mutable(repository)
        let state = try await amendState(repository)
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw DeskError("El mensaje no puede estar vacío.") }
        let attributes = try await commitAttributes(repository)
        var url: String?
        var remoteOID: String?
        if publish {
            _ = try await destination(repository, remote: remote, push: false)
            _ = try await fetch(repository, remote: remote, profile: profile)
            url = try await destination(repository, remote: remote, push: true)
            remoteOID = try await remoteTip(repository, url: url!, branch: state.branch, profile: profile)
            guard remoteOID == state.head else { throw DeskError("HEAD no coincide con la punta remota. No se permite reescribir esa rama.") }
        }
        return AmendPlan(repository: repository, oldHead: state.head, tree: attributes[0], parents: attributes[1],
                         author: attributes[2], branch: state.branch, oldMessage: attributes[3], newMessage: message,
                         destination: url, expectedRemote: remoteOID)
    }
    private func amendState(_ repository: Repository) async throws -> RepositorySnapshot {
        let state = try await snapshot(repository)
        guard ComparisonPair.validOID(state.head), !state.branch.isEmpty, state.branch != "(detached)" else {
            throw DeskError("Esta función requiere HEAD de una rama local.")
        }
        guard !state.files.contains(where: { $0.staged || $0.conflict }) else { throw DeskError("Desprepara los archivos y resuelve conflictos antes de editar el mensaje.") }
        for name in ["MERGE_HEAD", "CHERRY_PICK_HEAD", "REVERT_HEAD", "rebase-merge", "rebase-apply", "sequencer"] {
            let location = try await run(["rev-parse", "--git-path", name], directory: repository.path).text.trimmingCharacters(in: .whitespacesAndNewlines)
            let path = location.hasPrefix("/") ? location : repository.path + "/" + location
            if FileManager.default.fileExists(atPath: path) { throw DeskError("Hay una integración Git en curso. Complétala antes de editar HEAD.") }
        }
        return state
    }
    private func commitAttributes(_ repository: Repository) async throws -> [String] {
        let data = try await run(["show", "-s", "--format=%T%x00%P%x00%an <%ae> %at %ai%x00%B", "HEAD"], directory: repository.path).output
        let fields = data.split(separator: 0, omittingEmptySubsequences: false).map { String(decoding: $0, as: UTF8.self) }
        guard fields.count == 4 else { throw DeskError("No se pudieron verificar los metadatos de HEAD.") }
        return fields
    }
    private func remoteTip(_ repository: Repository, url: String, branch: String, profile: ConnectionProfile?) async throws -> String {
        try validateRemote(url)
        let result = try await network(["ls-remote", "--exit-code", "--", url, "refs/heads/" + branch], repository: repository, profile: profile, timeout: 10)
        let lines = result.text.split(separator: "\n")
        guard lines.count == 1, let oid = lines[0].split(separator: "\t").first, ComparisonPair.validOID(String(oid)) else {
            throw DeskError("La punta remota no se pudo verificar.")
        }
        return String(oid)
    }
    public func executeAmend(_ plan: AmendPlan, profile: ConnectionProfile?) async throws -> String {
        try await mutable(plan.repository)
        guard Date.now.timeIntervalSince(plan.created) < 60 else { throw DeskError("El plan de edición expiró.") }
        let state = try await amendState(plan.repository)
        let attributes = try await commitAttributes(plan.repository)
        guard state.head == plan.oldHead, state.branch == plan.branch, attributes[0] == plan.tree,
              attributes[1] == plan.parents, attributes[2] == plan.author else { throw DeskError("HEAD cambió. El plan quedó invalidado.") }
        if let url = plan.destination, let expected = plan.expectedRemote {
            guard try await remoteTip(plan.repository, url: url, branch: plan.branch, profile: profile) == expected else {
                throw DeskError("El remoto avanzó. El plan quedó invalidado.")
            }
        }
        _ = try await run(["update-ref", plan.recoveryReference, plan.oldHead, String(repeating: "0", count: plan.oldHead.count)], directory: plan.repository.path, trusted: true)
        let result = try await run(["commit", "--amend", "--only", "--file=-"], directory: plan.repository.path, trusted: true, input: Data(plan.newMessage.utf8))
        let after = try await amendState(plan.repository)
        let newAttributes = try await commitAttributes(plan.repository)
        guard newAttributes[0] == plan.tree, newAttributes[1] == plan.parents, newAttributes[2] == plan.author,
              after.branch == plan.branch, after.head != plan.oldHead else {
            throw DeskError("La edición produjo un estado inesperado. No se publicó; recuperación: " + plan.recoveryReference)
        }
        if let url = plan.destination, let expected = plan.expectedRemote {
            do {
                _ = try await network(["push", "--porcelain", "--force-with-lease=refs/heads/\(plan.branch):\(expected)",
                                      "--", url, after.head + ":refs/heads/" + plan.branch], repository: plan.repository, profile: profile)
                guard try await remoteTip(plan.repository, url: url, branch: plan.branch, profile: profile) == after.head else {
                    throw DeskError("No se pudo verificar la publicación.")
                }
            } catch {
                let publicationError = error
                let observed = try? await Task.detached {
                    try await self.remoteTip(plan.repository, url: url, branch: plan.branch, profile: profile)
                }.value
                if observed == after.head {
                    return result.text + "\nPublicación verificada tras una interrupción. Recuperación: " + plan.recoveryReference
                }
                throw DeskError("El mensaje se editó localmente, pero la publicación requiere revisión. Recuperación: \(plan.recoveryReference)\n\(publicationError.localizedDescription)")
            }
        }
        return result.text + "\nRecuperación conservada: " + plan.recoveryReference
    }
}
