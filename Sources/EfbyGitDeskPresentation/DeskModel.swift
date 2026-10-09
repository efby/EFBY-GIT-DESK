import Foundation
import AppKit
import Observation
import EfbyGitDeskApplication
import EfbyGitDeskDomain

private struct ReviewedSymbols {
    var fingerprint: Int
    var names: [String]
    var declarations: [CodeDeclaration]
}

@MainActor @Observable public final class DeskModel {
    public let service: DeskService
    @ObservationIgnored private let terminalFactory: @MainActor () -> any TerminalPort
    public var folderRoots: [String] = []
    public var repositories: [Repository] = []
    public var selectedID: String?
    public var openIDs: [String] = []
    public var snapshot = RepositorySnapshot()
    public var branches: [Branch] = []
    public var commits: [Commit] = []
    public var showReplaceComparison = false
    public private(set) var pendingComparisonCommit: Commit?
    public var selectedOIDs: [String] = []
    public private(set) var retainedCommits: [Commit] = []
    public private(set) var comparisonOrdering = false
    public private(set) var comparisonOrderFailed = false
    @ObservationIgnored private var selectionQuery: Task<Void, Never>?
    @ObservationIgnored private var loadedSearch = ""
    private var retainedOrder: [String] = []
    public func commitDetails(_ oid: String) -> Commit? {
        commits.first { $0.oid == oid } ?? retainedCommits.first { $0.oid == oid }
    }
    public var hiddenSelectedCommits: [Commit] {
        retainedCommits.filter { retained in selectedOIDs.contains(retained.oid) && !commits.contains { $0.oid == retained.oid } }
    }
    public var files: [FileChange] = []
    public var showAllFiles = false
    public private(set) var visibleFiles: [FileChange] = []
    public private(set) var fileInventoryRevision = 0
    var declarations: [CodeDeclaration] = []
    var callLinks: CodeCallLinks? { didSet { noteDocumentChange(callLinks != oldValue) } }
    var symbolJump: DiffJumpTarget?
    var linkTrail: [LinkReturn] = []
    @ObservationIgnored private var pendingRestore: CGPoint?
    @ObservationIgnored private var knownFiles: [String: FileChange] = [:]
    public var selectedFile: String?
    var openDocument: FileChange?
    public var diffText = ""
    public var comparison: FileComparison?
    public private(set) var diffDocumentRevision = 0
    public var diffRows: [DiffRow] = [] { didSet { noteDocumentChange(diffRows != oldValue) } }
    public var diffBlocks: [DiffChangeBlock] = []
    public var diffInline: [DiffInlineRow] = []
    public var diffMap: [DiffMapMark] = []
    public var diffLoading = false
    public var diffAligned = false
    public var syntaxLanguage: CodeLanguage = .automatic
    public var diffSyntax: DiffSyntax? { didSet { noteDocumentChange(diffSyntax != oldValue) } }
    public var diffNotice = ""
    public var search = ""
    public var repositorySearch = ""
    public var hasMore = false
    public var loading = false
    public var filesLoading = false
    public var workingView = false
    public var stagedView = false
    public var parentIndex = 0
    public var remoteNames: [String] = []
    public var remote = ""
    public var remoteSupported = false
    public var profiles: [ConnectionProfile] = []
    public var profileID = ""
    public var busy = false
    public var gitVersion = ""
    public var gitExecutable = ""
    public var status = "Abre un repositorio para comenzar."
    public var error: String?
    var bulkProgress: BulkRepositoryProgress?
    public var terminalVisible = false
    public var terminalHeight: Double = 230
    public var branchWidth: Double = 180
    public var detailWidth: Double = 340
    public var sidebarWidth: Double = 340
    public var terminals: [String: [TerminalTab]] = [:]
    public var selectedTerminal: UUID?
    public var plan: AmendPlan?
    public var showAmend = false
    public var amendText = ""
    public var publishAmend = false
    @ObservationIgnored private var loadedContext: DiffContext?
    @ObservationIgnored private var tips: [String] = []
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var operation: Task<Void, Never>?
    @ObservationIgnored private var query: Task<Void, Never>?
    @ObservationIgnored private var fileQuery: Task<Void, Never>?
    @ObservationIgnored private var highlightQuery: Task<Void, Never>?
    @ObservationIgnored private var diffQuery: Task<Void, Never>?
    @ObservationIgnored private var declarationQuery: Task<Void, Never>?
    @ObservationIgnored private var pendingReview: UUID?
    @ObservationIgnored private var reviewed: [String: ReviewedSymbols] = [:]
    @ObservationIgnored private var reviewedOrder: [String] = []
    @ObservationIgnored private var pendingSymbol: (fileID: String, symbol: CodeSymbol)?
    @ObservationIgnored private var layoutSave: Task<Void, Never>?
    @ObservationIgnored private var searchQuery: Task<Void, Never>?

    public init(service: DeskService, terminalFactory: @escaping @MainActor () -> any TerminalPort) {
        self.service = service; self.terminalFactory = terminalFactory
    }
    public var sidebarSelection: String? {
        get { selectedID }
        set {
            guard let newValue, repositories.contains(where: { $0.id == newValue }) else { return }
            selectedID = newValue
        }
    }
    public var repository: Repository? { repositories.first { $0.id == selectedID } }
    public var mutable: Bool { repository?.trusted == true && repository?.linkedWorktree == false && repository?.inspectionReason == nil && !busy }
    public var profile: ConnectionProfile? { profiles.first { $0.id == profileID } }
    public var workspaceSection: WorkspaceSection {
        get { workingView ? (stagedView ? .staged : .pending) : .history }
        set {
            guard newValue != workspaceSection else { return }
            switch newValue {
            case .history: workingView = false; loadFiles()
            case .pending, .staged:
                guard repository?.trusted == true else { return }
                showWorking(staged: newValue == .staged)
            }
        }
    }
    public var context: DiffContext? {
        if workingView { return stagedView ? .staged : .working }
        if comparisonOrdering || comparisonOrderFailed { return nil }
        if selectedOIDs.count == 2, let pair = try? ComparisonPair(base: orderedComparison[0], target: orderedComparison[1]) {
            return .commits(pair)
        }
        if let oid = selectedOIDs.first { return .commit(oid, parent: parentIndex) }
        return nil
    }
    /// The displayed topological order, rather than click order or commit timestamps.
    public var orderedComparison: [String] {
        if retainedOrder.count == 2, Set(retainedOrder) == Set(selectedOIDs) { return retainedOrder }
        return selectedOIDs.sorted { lhs, rhs in
            (commits.firstIndex { $0.oid == lhs } ?? -1) > (commits.firstIndex { $0.oid == rhs } ?? -1)
        }
    }
    public var detectedLanguageLabel: String {
        guard let file = openedFile() else { return "" }
        return (syntaxLanguage == .automatic ? CodeLanguage.detect(path: file.name) : syntaxLanguage).rawValue
    }
    private func noteDocumentChange(_ changed: Bool) {
        if changed { diffDocumentRevision &+= 1 }
    }
    public func refreshHighlighting() {
        scheduleCallResolution()
        highlightQuery?.cancel()
        guard let file = openedFile(), diffAligned else { return }
        let rows = diffRows; let language = syntaxLanguage; let version = generation; let currentContext = context
        let oldName = file.oldPath.flatMap { String(data: $0, encoding: .utf8) } ?? file.name
        let before = language == .automatic ? CodeLanguage.detect(path: oldName) : language
        let after = language == .automatic ? CodeLanguage.detect(path: file.name) : language
        highlightQuery = Task {
            let syntax = await Task.detached { CodeHighlighter.highlight(rows: rows, before: before, after: after) }.value
            guard !Task.isCancelled, generation == version, selectedFile == file.id,
                  syntaxLanguage == language, context == currentContext, diffRows == rows else { return }
            diffSyntax = syntax
        }
    }
    public var currentTerminals: [TerminalTab] { terminals[selectedID ?? ""] ?? [] }
    public var activeTerminal: TerminalTab? {
        currentTerminals.first { $0.id == selectedTerminal } ?? currentTerminals.first
    }
    public var activeTerminalCount: Int { terminals.values.flatMap { $0 }.filter { $0.driver.running }.count }
    public func load() async {
        do {
            repositories = try await service.registry.repositories()
            folderRoots = try await service.folderRoots()
            profiles = try await service.registry.profiles()
            terminalVisible = try await service.registry.preference("terminal.visible") == "true"
            terminalHeight = Double(try await service.registry.preference("terminal.height") ?? "") ?? 230
            if let saved = try await service.registry.preference("repository.tabs"), let data = saved.data(using: .utf8) {
                openIDs = (try? JSONDecoder().decode([String].self, from: data))?.filter { id in repositories.contains { $0.id == id } } ?? []
            }
            branchWidth = Double(try await service.registry.preference("panel.branches") ?? "") ?? 180
            detailWidth = Self.panelWidth(try await service.registry.preference("workspace.detailWidth"), default: 340, minimum: 340)
            sidebarWidth = Self.panelWidth(try await service.registry.preference("workspace.sidebarWidth"), default: 340, minimum: 210, maximum: 340)
            if let savedGit = try await service.registry.preference("git.executable"), !savedGit.isEmpty {
                try await service.git.configureExecutable(path: savedGit)
            }
            gitVersion = try await service.git.version()
            gitExecutable = try await service.git.executablePath()
            let savedSelection = try await service.registry.preference("repository.selected")
            if let savedSelection, repositories.contains(where: { $0.id == savedSelection }) {
                _ = try await service.open(path: savedSelection)
                repositories = try await service.registry.repositories()
                selectedID = savedSelection
            }
            if let selectedID, !openIDs.contains(selectedID), repository != nil { openIDs.append(selectedID) }
            if repository != nil { refresh() }
        } catch { self.error = error.localizedDescription }
    }
    public func chooseRepository() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.prompt = "Abrir carpeta"
        panel.message = "Elige un repositorio o una carpeta que contenga proyectos Git. Se buscará en todas sus subcarpetas."
        if panel.runModal() == .OK, let url = panel.url { open(path: url.path) }
    }
    public func open(path: String) {
        perform("Buscando repositorios en la carpeta y sus subcarpetas…", refreshAfter: false) {
            let result: FolderOpenResult
            do { result = try await self.service.openFolder(path: path) }
            catch {
                self.repositories = (try? await self.service.registry.repositories()) ?? self.repositories
                self.folderRoots = (try? await self.service.folderRoots()) ?? self.folderRoots
                throw error
            }
            self.repositories = try await self.service.registry.repositories()
            self.folderRoots = try await self.service.folderRoots()
            self.repositorySearch = ""
            if let repository = result.repositories.first(where: { $0.path == result.root }) ?? (result.repositories.count == 1 ? result.repositories.first : nil) {
                self.select(repository.id)
            }
            self.status = "\(result.repositories.count) repositorios encontrados en " + URL(fileURLWithPath: result.root).lastPathComponent
            if !result.issues.isEmpty { self.error = result.issues.prefix(12).joined(separator: "\n") }
        }
    }
    public func chooseGitExecutable() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true; panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        panel.title = "Selecciona el ejecutable Git de tu cuenta"
        if panel.runModal() == .OK, let url = panel.url { configureGit(path: url.path) }
    }
    public func configureGit(path: String) {
        guard !busy else { return }
        generation += 1; query?.cancel(); searchQuery?.cancel(); loading = false
        perform("Validando Git…", refreshAfter: false) {
            let preferred = path.trimmingCharacters(in: .whitespacesAndNewlines)
            try await self.service.git.configureExecutable(path: preferred.isEmpty ? nil : preferred)
            self.gitVersion = try await self.service.git.version()
            self.gitExecutable = try await self.service.git.executablePath()
            try await self.service.registry.setPreference("git.executable", value: preferred)
            self.status = "Git disponible para tu cuenta: " + self.gitExecutable
            self.refresh(forceHistory: true)
        }
    }
    public func select(_ id: String) {
        guard repositories.contains(where: { $0.id == id }) else { return }
        if !openIDs.contains(id) { openIDs.append(id); persistTabs() }
        generation += 1; query?.cancel(); searchQuery?.cancel(); selectionQuery?.cancel(); comparisonOrdering = false; comparisonOrderFailed = false; fileQuery?.cancel(); closeDiff(); knownFiles = [:]; filesLoading = false
        pendingComparisonCommit = nil; showReplaceComparison = false
        selectedID = id; selectedOIDs = []; retainedCommits = []; retainedOrder = []; commits = []; files = []; diffText = ""
        workingView = false; tips = []; parentIndex = 0; selectedTerminal = nil
        snapshot = RepositorySnapshot(); branches = []; remoteNames = []; remote = ""; remoteSupported = false; loadedContext = nil
        Task { try? await service.registry.setPreference("repository.selected", value: id) }
        refresh()
    }
    public func trust() {
        guard let repository else { return }
        perform("Activando repositorio confiable…") {
            _ = try await self.service.trust(repository)
            self.repositories = try await self.service.registry.repositories()
        }
    }
    public func trustAll(ids: [String]) {
        guard !ids.isEmpty, !busy else { return }
        let progress = BulkRepositoryProgress(kind: .trusted)
        bulkProgress = progress
        perform("Verificando y confiando en los repositorios seleccionados…") {
            do {
                let report = try await self.service.trustAll(ids: ids) { event in await progress.apply(event) }
                self.repositories = (try? await self.service.registry.repositories()) ?? self.repositories
                progress.finish(report)
                self.status = "Confianza: \(report.completed) completados, \(report.skipped) omitidos, \(report.failed) con error."
            } catch is CancellationError {
                progress.finish(BulkRepositoryReport(kind: .trusted, entries: progress.entries, cancelled: true))
                throw CancellationError()
            } catch { progress.fail(error); throw error }
        }
    }
    public func fetchAll() {
        guard !repositories.isEmpty, !busy else { return }
        let profile = profile
        let progress = BulkRepositoryProgress(kind: .fetch)
        bulkProgress = progress
        perform("Obteniendo cambios de todos los repositorios…") {
            do {
                let report = try await self.service.fetchAll(profile: profile) { event in await progress.apply(event) }
                progress.finish(report)
                self.status = "Fetch: \(report.completed) completados, \(report.skipped) omitidos, \(report.failed) con error."
            } catch is CancellationError {
                progress.finish(BulkRepositoryReport(kind: .fetch, entries: progress.entries, cancelled: true))
                throw CancellationError()
            } catch { progress.fail(error); throw error }
        }
    }
    public func update(_ repository: Repository) {
        Task {
            do { try await service.registry.save(repository); repositories = try await service.registry.repositories() }
            catch { self.error = error.localizedDescription }
        }
    }
    public func remove(_ repository: Repository) {
        guard !busy else { return }
        guard confirmClosingSessions(repository.id) else { return }
        openIDs.removeAll { $0 == repository.id }; persistTabs()
        terminals[repository.id]?.forEach { $0.driver.close() }
        terminals.removeValue(forKey: repository.id)
        Task {
            do {
                try await service.registry.remove(id: repository.id)
                repositories = try await service.registry.repositories()
                if selectedID == repository.id { selectedID = nil; commits = []; files = []; diffText = ""; try await service.registry.setPreference("repository.selected", value: "") }
            } catch { self.error = error.localizedDescription }
        }
    }
    private func confirmClosingSessions(_ id: String) -> Bool {
        guard terminals[id]?.contains(where: { $0.driver.running }) == true else { return true }
        let alert = NSAlert(); alert.messageText = "Cerrar sesiones del terminal"
        alert.informativeText = "Las sesiones y sus procesos recibirán una señal de cierre. Tus archivos se conservan."
        alert.addButton(withTitle: "Cerrar sesiones"); alert.addButton(withTitle: "Cancelar")
        return alert.runModal() == .alertFirstButtonReturn
    }
    public func closeRepository(_ id: String) {
        guard !busy, confirmClosingSessions(id) else { return }
        terminals[id]?.forEach { $0.driver.close() }; terminals.removeValue(forKey: id)
        openIDs.removeAll { $0 == id }; persistTabs()
        if selectedID == id {
            selectedID = nil; commits = []; files = []; diffText = ""
            if let next = openIDs.last { select(next) }
            else { Task { try? await service.registry.setPreference("repository.selected", value: "") } }
        }
    }
    private func persistTabs() {
        guard let data = try? JSONEncoder().encode(openIDs), let value = String(data: data, encoding: .utf8) else { return }
        Task { try? await service.registry.setPreference("repository.tabs", value: value) }
    }
    public func refresh(forceHistory: Bool = false) {
        guard let repository else { return }
        generation += 1; let version = generation
        query?.cancel(); loading = true
        let search = search
        query = Task {
            defer { if version == generation { loading = false } }
            do {
                async let state = service.git.snapshot(repository)
                async let refs = service.git.branches(repository)
                let (newState, newBranches) = try await (state, refs)
                let newTips = Array(Set(newBranches.map(\.oid) + [newState.head])).filter(ComparisonPair.validOID).sorted()
                let newRemotes = repository.trusted ? try await service.git.remotes(repository) : []
                let selectedRemote = newRemotes.contains(remote) ? remote : (newRemotes.first ?? "")
                let supported = repository.trusted && !selectedRemote.isEmpty ? await service.git.remoteSupported(repository, remote: selectedRemote) : false
                let changed = newTips != tips || forceHistory || commits.isEmpty
                let history = changed ? try await service.git.history(repository, tips: newTips, offset: 0, search: search) : commits
                guard !Task.isCancelled, version == generation, repository.id == selectedID, search == self.search else { return }
                snapshot = newState; branches = newBranches; remoteNames = newRemotes
                remote = selectedRemote; remoteSupported = supported
                if changed {
                    commits = history; hasMore = history.count == 100; tips = newTips; loadedSearch = search
                }
                if let plan, plan.oldHead != newState.head || newState.files.contains(where: \.staged) { cancelPlan() }
                loadFiles()
            } catch is CancellationError {} catch {
                guard version == generation else { return }
                self.error = error.localizedDescription
            }
        }
    }
    public func searchHistory() {
        searchQuery?.cancel()
        searchQuery = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            refresh(forceHistory: true)
        }
    }
    public func loadMore() {
        guard let repository, hasMore, !busy, !loading, search == loadedSearch else { return }
        let offset = commits.count; let tips = tips; let search = search; let version = generation
        perform("Cargando más historial…", refreshAfter: false) {
            let page = try await self.service.git.history(repository, tips: tips, offset: offset, search: search)
            guard version == self.generation, search == self.search, repository.id == self.selectedID else { return }
            self.commits += page; self.hasMore = page.count == 100
        }
    }
    public func chooseCommit(_ commit: Commit) {
        if selectedOIDs.count == 2, !selectedOIDs.contains(commit.oid) {
            pendingComparisonCommit = commit; showReplaceComparison = true
            return
        }
        workingView = false; parentIndex = 0
        if selectedOIDs.contains(commit.oid) { selectedOIDs.removeAll { $0 == commit.oid } }
        else if selectedOIDs.count < 2 { selectedOIDs.append(commit.oid) }
        selectionQuery?.cancel(); comparisonOrdering = false; comparisonOrderFailed = false
        retainedOrder = orderedComparison
        retainedCommits = selectedOIDs.compactMap { oid in oid == commit.oid ? commit : commitDetails(oid) }
        if selectedOIDs.count == 2, !selectedOIDs.allSatisfy({ oid in commits.contains { $0.oid == oid } }), let repository {
            let selected = selectedOIDs, tips = tips
            comparisonOrdering = true; loadFiles()
            selectionQuery = Task {
                do {
                    let order = try await service.git.comparisonOrder(repository, tips: tips, selected: selected)
                    guard !Task.isCancelled, repository.id == selectedID, selected == selectedOIDs else { return }
                    retainedOrder = order; comparisonOrdering = false; loadFiles()
                } catch {
                    guard !Task.isCancelled, repository.id == selectedID, selected == selectedOIDs else { return }
                    comparisonOrdering = false; comparisonOrderFailed = true
                    self.error = error.localizedDescription
                    // Leave the comparison blocked rather than inventing its direction.
                }
            }
            return
        }
        loadFiles()
    }
    public func resolveComparisonReplacement(accept: Bool) {
        let commit = pendingComparisonCommit
        pendingComparisonCommit = nil; showReplaceComparison = false
        guard accept, let commit else { return }
        selectedOIDs = []; retainedCommits = []; retainedOrder = []
        chooseCommit(commit)
    }
    public func showWorking(staged: Bool) {
        selectionQuery?.cancel(); comparisonOrdering = false; comparisonOrderFailed = false
        pendingComparisonCommit = nil; showReplaceComparison = false
        workingView = true; stagedView = staged; selectedOIDs = []; retainedCommits = []; retainedOrder = []; loadFiles()
    }
    public func loadFiles() {
        fileQuery?.cancel()
        declarationQuery?.cancel()
        pendingReview = nil
        if context == .working || context == .staged { callLinks = nil }
        guard let repository, let context else {
            files = []; visibleFiles = []; knownFiles = [:]; fileInventoryRevision += 1; closeDiff(); loadedContext = nil; filesLoading = false; return
        }
        if loadedContext != context {
            files = []; visibleFiles = []; declarations = []; knownFiles = [:]; fileInventoryRevision += 1; closeDiff(); loadedContext = context
        }
        let version = generation; filesLoading = true
        fileQuery = Task {
            defer { if version == generation && self.context == context { filesLoading = false } }
            do {
                let newFiles = try await service.git.changes(repository, context: context)
                guard !Task.isCancelled, version == generation, self.context == context else { return }
                files = newFiles
                if showAllFiles {
                    let all = try await service.git.allFiles(repository, context: context)
                    guard !Task.isCancelled, version == generation, self.context == context, showAllFiles else { return }
                    let changed = Set(newFiles.map(\.path))
                    visibleFiles = (newFiles + all.filter { !changed.contains($0.path) })
                        .sorted { $0.path.lexicographicallyPrecedes($1.path) }
                } else { visibleFiles = newFiles }
                fileInventoryRevision += 1
                if let selectedFile, visibleFiles.contains(where: { $0.id == selectedFile }) {
                    if comparison == nil || openDocument?.id != selectedFile { loadDiff(id: selectedFile) }
                    else { scheduleCallResolution() }
                } else if openDocument?.id == selectedFile, comparison != nil {
                    scheduleCallResolution()
                } else { closeDiff() }
            } catch is CancellationError {} catch {
                if version == generation && self.context == context {
                    visibleFiles = []; fileInventoryRevision += 1; closeDiff()
                    self.error = error.localizedDescription
                }
            }
        }
    }
    public func setShowAllFiles(_ value: Bool) {
        guard showAllFiles != value else { return }
        showAllFiles = value
        loadFiles()
    }
    private func scheduleCallResolution() {
        guard diffAligned, let repository, let context,
              let file = openDocument, file.id == selectedFile else { return }
        let source = comparison?.after ?? comparison?.before ?? ""
        let key = reviewKey(repositoryID: repository.id, context: context, fileID: file.id)
        let cacheable = context != .working && context != .staged
        declarationQuery?.cancel()
        let requestID = UUID()
        pendingReview = requestID
        let oldName = file.oldPath.flatMap { String(data: $0, encoding: .utf8) } ?? file.name
        let beforeLanguage = syntaxLanguage == .automatic ? CodeLanguage.detect(path: oldName) : syntaxLanguage
        let afterLanguage = syntaxLanguage == .automatic ? CodeLanguage.detect(path: file.name) : syntaxLanguage
        let rows = diffRows
        let beforeSide = comparison?.after == nil
        let version = generation
        let fileID = file.id
        let visible = visibleFiles
        declarationQuery = Task {
            defer { if pendingReview == requestID { pendingReview = nil } }
            let prepared = await Task.detached {
                (CodeCallIndex.fingerprint(source), CodeImportIndex.scope(in: source, language: afterLanguage, filePath: file.name), CodeSymbolIndex.classSpans(text: source, language: afterLanguage))
            }.value
            let fingerprint = prepared.0
            let scope = prepared.1
            let classes = prepared.2
            if cacheable, let saved = reviewed[key], saved.fingerprint == fingerprint {
                guard !Task.isCancelled, version == generation, selectedFile == fileID else { return }
                await publish(saved.declarations, fileID: fileID, rows: rows, before: beforeLanguage, after: afterLanguage, scope: scope, classes: classes, requestID: requestID, repositoryID: repository.id, context: context, version: version)
                return
            }
            let names = await Task.detached {
                CodeCallIndex.callNames(rows: rows, beforeLanguage: beforeLanguage, afterLanguage: afterLanguage)
            }.value
            if cacheable, let saved = reviewed[key], saved.names == names {
                remember(key, ReviewedSymbols(fingerprint: fingerprint, names: names, declarations: saved.declarations))
                guard !Task.isCancelled, version == generation, selectedFile == fileID else { return }
                await publish(saved.declarations, fileID: fileID, rows: rows, before: beforeLanguage, after: afterLanguage, scope: scope, classes: classes, requestID: requestID, repositoryID: repository.id, context: context, version: version)
                return
            }
            let own = await Task.detached {
                CodeCallIndex.declarations(file: file, text: source, before: beforeSide)
            }.value
            var found = own
            if !names.isEmpty {
                let hits = (try? await service.git.declarationHits(repository, context: context, names: names)) ?? []
                let wanted = Set(names)
                let byPath = Dictionary(visible.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
                let remote = await Task.detached {
                    hits.flatMap { hit -> [CodeDeclaration] in
                        guard hit.path != file.name else { return [] }
                        let candidate = byPath[hit.path] ?? FileChange(path: Data(hit.path.utf8), status: "=")
                        let language = CodeLanguage.detect(path: hit.path)
                        let parsed = CodeSymbolIndex.make(text: hit.text, language: language)
                        let symbols = parsed.map(\.name).filter { wanted.contains($0) }
                        let names = symbols.isEmpty ? wanted.filter { CodeCallIndex.isDeclarationLine(hit.text, name: $0, language: language) } : symbols
                        return names.map { name in
                            CodeDeclaration(fileID: candidate.id, path: hit.path, name: name, line: hit.line, before: false, owner: parsed.first { $0.name == name }?.owner, isType: parsed.first { $0.name == name }?.isType ?? false)
                        }
                    }
                }.value
                found.append(contentsOf: remote)
            }
            guard !Task.isCancelled, version == generation, selectedFile == fileID else { return }
            if cacheable { remember(key, ReviewedSymbols(fingerprint: fingerprint, names: names, declarations: found)) }
            await publish(found, fileID: fileID, rows: rows, before: beforeLanguage, after: afterLanguage, scope: scope, classes: classes, requestID: requestID, repositoryID: repository.id, context: context, version: version)
        }
    }
    private func reviewKey(repositoryID: String, context: DiffContext, fileID: String) -> String {
        let scope: String
        switch context {
        case .commits(let pair): scope = pair.base + ".." + pair.target
        case .commit(let oid, let parent): scope = oid + "#" + String(parent)
        case .staged: scope = "staged"
        case .working: scope = "working"
        }
        return repositoryID + "\n" + scope + "\n" + fileID
    }
    private func remember(_ key: String, _ value: ReviewedSymbols) {
        if reviewed[key] == nil { reviewedOrder.append(key) }
        reviewed[key] = value
        while reviewedOrder.count > 48 {
            reviewed.removeValue(forKey: reviewedOrder.removeFirst())
        }
    }
    private func publish(_ found: [CodeDeclaration], fileID: String, rows: [DiffRow], before: CodeLanguage, after: CodeLanguage, scope: CodeFileScope, classes: [CodeClassSpan], requestID: UUID, repositoryID: String, context: DiffContext, version: Int) async {
        let links = await Task.detached {
            CodeCallIndex.links(rows: rows, beforeLanguage: before, afterLanguage: after, declarations: found, currentFileID: fileID, imports: scope.imports, receivers: scope.receivers, libraries: scope.libraries, classes: classes)
        }.value
        guard !Task.isCancelled, pendingReview == requestID, generation == version,
              selectedID == repositoryID, self.context == context,
              selectedFile == fileID, diffRows == rows else { return }
        for declaration in found {
            guard knownFiles[declaration.fileID] == nil, let data = declaration.path.data(using: .utf8) else { continue }
            let candidate = visibleFiles.first { $0.id == declaration.fileID } ?? FileChange(path: data, status: "=")
            if candidate.id == declaration.fileID { knownFiles[declaration.fileID] = candidate }
        }
        declarations = found
        if callLinks != links { callLinks = links }
    }
    func followDeclaration(fileID: String, line: Int, before: Bool, name: String, callLine: Int, scrollX: CGFloat = 0, scrollY: CGFloat = 0) {
        if let current = selectedFile, current != fileID {
            linkTrail.append(LinkReturn(fileID: current, line: max(callLine, 1), name: openDocument?.name ?? "", offsetX: scrollX, offsetY: scrollY))
            if linkTrail.count > 64 { linkTrail.removeFirst(linkTrail.count - 64) }
        }
        navigateToSymbol(fileID: fileID, symbol: CodeSymbol(name: name, line: line, before: before), preserveTrail: true)
    }
    func returnAlongLink() {
        guard let previous = linkTrail.popLast() else { return }
        navigateToSymbol(fileID: previous.fileID, symbol: CodeSymbol(name: "", line: previous.line, before: false), preserveTrail: true, restoreOffset: CGPoint(x: previous.offsetX, y: previous.offsetY))
    }
    func navigateToSymbol(fileID: String, symbol: CodeSymbol, preserveTrail: Bool = false, restoreOffset: CGPoint? = nil) {
        pendingSymbol = (fileID, symbol)
        pendingRestore = restoreOffset
        if selectedFile == fileID, comparison != nil, !diffRows.isEmpty { applySymbolJump() }
        else { loadDiff(id: fileID, preserveTrail: preserveTrail) }
    }
    private func applySymbolJump() {
        guard let pendingSymbol, selectedFile == pendingSymbol.fileID else { return }
        let line = pendingSymbol.symbol.line
        guard let row = diffRows.firstIndex(where: { pendingSymbol.symbol.before ? $0.beforeNumber == line : $0.afterNumber == line }) else { return }
        symbolJump = DiffJumpTarget(row: row, restoreOffset: pendingRestore)
        self.pendingSymbol = nil
        pendingRestore = nil
    }
    private func openedFile() -> FileChange? {
        if let selectedFile, let file = file(id: selectedFile) { return file }
        return openDocument
    }
    private func file(id: String) -> FileChange? {
        if let visible = visibleFiles.first(where: { $0.id == id }) { return visible }
        if let known = knownFiles[id] { return known }
        if openDocument?.id == id { return openDocument }
        guard let declaration = declarations.first(where: { $0.fileID == id }),
              let data = declaration.path.data(using: .utf8) else { return nil }
        let candidate = FileChange(path: data, status: "=")
        return candidate.id == id ? candidate : nil
    }
    public func closeDiff() {
        diffQuery?.cancel(); highlightQuery?.cancel()
        selectedFile = nil; openDocument = nil; diffText = ""; diffSyntax = nil; symbolJump = nil; pendingSymbol = nil; callLinks = nil; linkTrail = []
        comparison = nil; diffRows = []; diffBlocks = []; diffMap = []; diffInline = []; diffLoading = false; diffAligned = false; diffNotice = ""
    }
    public func loadDiff(id: String, preserveTrail: Bool = false) {
        if !preserveTrail { linkTrail = [] }
        diffQuery?.cancel()
        guard let repository, let context, let file = file(id: id) else { return }
        knownFiles[file.id] = file
        let preserveView = selectedFile == id && comparison != nil
        if selectedFile != id { symbolJump = nil; callLinks = nil }
        selectedFile = id
        openDocument = file
        if !preserveView {
            diffText = ""; comparison = nil; diffRows = []; diffBlocks = []; diffMap = []; diffInline = []; diffSyntax = nil
            diffLoading = true; diffAligned = false; diffNotice = ""
        }
        let version = generation
        diffQuery = Task {
            do {
                let result = try await service.git.fileComparison(repository, context: context, file: file)
                let alignment = await Task.detached { () -> Result<DiffLayout, Error> in
                    Result { DiffLayout(rows: try DiffAlignment.make(result)) }
                }.value
                guard !Task.isCancelled, version == generation, selectedFile == id, self.context == context else { return }
                comparison = result; diffNotice = result.notice
                switch alignment {
                case .success(let layout):
                    if diffRows != layout.rows { diffSyntax = nil }
                    diffRows = layout.rows; diffBlocks = layout.blocks; diffMap = layout.map; diffInline = layout.inline; diffAligned = true
                    if layout.inline.contains(where: \.limited) { diffNotice += "\nEn líneas extensas o complejas, se destaca el tramo modificado entre el prefijo y sufijo comunes." }
                case .failure(let error): diffRows = []; diffBlocks = []; diffMap = []; diffInline = []; diffSyntax = nil; diffAligned = false; diffNotice += "\n" + error.localizedDescription
                }
                applySymbolJump()
                diffLoading = false
                refreshHighlighting()
                diffText = result.patch.isEmpty
                    ? (file.status == "=" ? "Sin cambios; se muestran ambos documentos completos." : "Cambio de metadatos o modo; los documentos se muestran completos.")
                    : result.patch
            } catch is CancellationError {} catch { if !Task.isCancelled, version == generation, selectedFile == id, self.context == context { self.error = error.localizedDescription; diffLoading = false } }
        }
    }
    public func mutate(_ action: GitAction) {
        guard let repository else { return }
        let profile = profile
        perform("Ejecutando operación Git…") {
            let result = try await self.service.mutate(action, repository: repository, profile: profile)
            self.status = result.isEmpty ? "Operación completada." : String(result.prefix(700))
        }
    }
    public func perform(_ label: String, refreshAfter: Bool = true, action: @escaping @MainActor () async throws -> Void) {
        guard !busy else { return }
        busy = true; status = label; error = nil
        operation = Task {
            defer {
                busy = false; operation = nil
                if refreshAfter { refresh() }
            }
            do { try await action() }
            catch is CancellationError { status = "Operación cancelada. Se consultará el estado real del repositorio." }
            catch { self.error = error.localizedDescription; status = "La operación requiere revisión." }
        }
    }
    public func cancelOperation() { operation?.cancel() }
    public func saveConnection(email: String, token: String) {
        perform("Guardando conexión en Keychain…", refreshAfter: false) {
            let profile = try await self.service.cloud.saveToken(email: email, token: token)
            try await self.service.registry.saveProfile(profile)
            self.profiles = try await self.service.registry.profiles()
            self.profileID = profile.id; self.status = "Token guardado en Keychain."
        }
    }
    public func disconnect(_ profile: ConnectionProfile) {
        perform("Retirando conexión local…", refreshAfter: false) {
            try await self.service.cloud.removeToken(profile: profile)
            try await self.service.registry.removeProfile(id: profile.id)
            self.profiles = try await self.service.registry.profiles(); self.profileID = ""
        }
    }
    public func clone(source: String, destination: String) {
        let profile = profile
        perform("Clonando sin checkout. Puedes cancelar…") {
            let repository = try await self.service.clone(source: source, destination: destination, profile: profile)
            self.repositories = try await self.service.registry.repositories()
            self.select(repository.id); self.status = "Clonación completada. Revisa y autoriza la confianza antes del checkout."
        }
    }
    public func beginAmend() {
        guard let repository, !snapshot.head.isEmpty else { return }
        let oid = snapshot.head
        perform("Leyendo mensaje de HEAD…", refreshAfter: false) {
            self.amendText = try await self.service.git.message(repository, oid: oid)
            self.publishAmend = false; self.showAmend = true
        }
    }
    public func prepareAmend() {
        guard let repository else { return }
        let message = amendText; let publish = publishAmend; let remote = remote; let profile = profile
        if publish { currentTerminals.forEach { $0.driver.inputPaused = true } }
        perform("Verificando plan de edición…", refreshAfter: false) {
            do {
                self.plan = try await self.service.prepareAmend(repository, message: message, publish: publish, remote: remote, profile: profile)
                self.showAmend = false
            } catch { self.unpause(); throw error }
        }
    }
    public func executePlan() {
        guard let plan else { return }
        let profile = profile
        perform("Editando mensaje y verificando recuperación…") {
            defer { self.plan = nil; self.unpause() }
            self.status = try await self.service.amend(planID: plan.id, profile: profile)
        }
    }
    public func cancelPlan() { guard !busy else { return }; if let plan { Task { await service.cancelPlan(plan.id) } }; plan = nil; unpause() }
    public func unpause() { terminals.values.flatMap { $0 }.forEach { $0.driver.inputPaused = false } }
    public func startTerminal() {
        guard let repository, mutable else { return }
        perform("Verificando confianza para el terminal…", refreshAfter: false) {
            let directory = try await self.service.authorizeTerminal(repository)
            let driver = self.terminalFactory()
            try driver.start(directory: directory, columns: 100, rows: 24)
            let tab = TerminalTab(title: "Terminal \((self.terminals[repository.id]?.count ?? 0) + 1)", driver: driver)
            self.terminals[repository.id, default: []].append(tab); self.selectedTerminal = tab.id
            self.terminalVisible = true; self.persistLayout(); self.status = "Terminal activo en " + repository.name
        }
    }
    public func closeTerminal(_ tab: TerminalTab) {
        if tab.driver.running {
            let alert = NSAlert(); alert.messageText = "Cerrar sesión del terminal"
            alert.informativeText = "La shell y sus procesos recibirán una señal de cierre."
            alert.addButton(withTitle: "Cerrar sesión"); alert.addButton(withTitle: "Cancelar")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        tab.driver.close()
        terminals[selectedID ?? ""]?.removeAll { $0.id == tab.id }
        selectedTerminal = currentTerminals.first?.id; refresh()
    }
    public func closeAllTerminals() { terminals.values.flatMap { $0 }.forEach { $0.driver.close() } }
    static func panelWidth(_ saved: String?, default fallback: Double, minimum: Double, maximum: Double = .greatestFiniteMagnitude) -> Double {
        guard let saved, let value = Double(saved), value.isFinite else { return fallback }
        return min(maximum, max(minimum, value))
    }
    public func persistLayout() {
        layoutSave?.cancel()
        let visible = terminalVisible; let height = terminalHeight
        let branches = branchWidth; let detail = detailWidth; let sidebar = sidebarWidth
        layoutSave = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            try? await service.registry.setPreference("terminal.visible", value: String(visible))
            try? await service.registry.setPreference("terminal.height", value: String(height))
            try? await service.registry.setPreference("panel.branches", value: String(branches))
            try? await service.registry.setPreference("workspace.detailWidth", value: String(detail))
            try? await service.registry.setPreference("workspace.sidebarWidth", value: String(sidebar))
        }
    }
}
