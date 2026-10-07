import Foundation
import AppKit
import SwiftUI
import Testing
import EfbyGitDeskDomain
import EfbyGitDeskApplication
import EfbyGitDeskInfrastructure
@testable import EfbyGitDeskPresentation

struct ComparisonPanelTests {
    @Test func treePreservesRawPathsAndFileDirectoryReplacement() {
        let files = [
            FileChange(path: Data("src".utf8), status: "D"),
            FileChange(path: Data("src/custom/main.py".utf8), status: "A"),
            FileChange(path: Data([116, 101, 115, 116, 47, 255]), status: "M"),
            FileChange(path: Data("src/custom/old.py".utf8), oldPath: Data("old.py".utf8), status: "R100")
        ]
        let nodes = ComparisonFileNode.make(files)
        func leaves(_ nodes: [ComparisonFileNode]) -> [FileChange] {
            nodes.flatMap { node in node.file.map { [$0] } ?? leaves(node.children) }
        }
        #expect(Set(leaves(nodes)) == Set(files))
        #expect(Set(nodes.map(\.id)).count == nodes.count)
        #expect(nodes.reduce(0) { $0 + $1.count } == 4)
        #expect(nodes.contains { $0.file == nil && $0.name == "src" && $0.count == 2 })
    }

    @MainActor @Test func panelPreviewPreservesComparisonDirection() async throws {
        let f = try await GitFixture.make(); defer { f.cleanup() }
        let registry = try SQLiteRegistry(path: f.folder.appendingPathComponent("catalog.sqlite").path)
        let service = DeskService(git: f.adapter, registry: registry, cloud: BitbucketClient(vault: KeychainVault()))
        let model = DeskModel(service: service, terminalFactory: { PTYTerminal(shell: "/bin/sh", login: false) })
        let newer = Commit(oid: String(repeating: "a", count: 40), parents: [],
            message: "Mejorar el manejo de solicitudes", author: "Raúl Rodríguez", date: "2026-09-22T10:41:00-03:00", references: "")
        let older = Commit(oid: String(repeating: "b", count: 40), parents: [],
            message: "Permitir operaciones del repositorio", author: "Josué Vera", date: "2026-09-16T16:36:00-03:00", references: "")
        model.commits = [newer, older]; model.selectedOIDs = [newer.oid, older.oid]
        model.files = ["src/custom/handler.py", "src/lambda_handler.py", "tests/test_cases/test_lambda_handler.py", "tests/test_rules.py"].map {
            FileChange(path: Data($0.utf8), status: "M")
        }
        #expect(model.orderedComparison == [older.oid, newer.oid])
        if let path = ProcessInfo.processInfo.environment["EFBY_PANEL_PREVIEW_PATH"] {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 750), styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            defer { window.close() }
            let hosting = NSHostingView(rootView: DiffPane(model: model).environment(\.colorScheme, .dark))
            hosting.sizingOptions = []
            window.contentView = hosting
            hosting.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(150))
            hosting.layoutSubtreeIfNeeded()
            let bitmap = try #require(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
            hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
            try #require(bitmap.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: path))
        }
    }
}
