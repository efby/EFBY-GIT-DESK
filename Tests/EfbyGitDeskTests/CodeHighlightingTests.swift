import Foundation
import Testing
import AppKit
import SwiftUI
import EfbyGitDeskDomain
import EfbyGitDeskApplication
import EfbyGitDeskInfrastructure
@testable import EfbyGitDeskPresentation

struct CodeHighlightingTests {
    @Test func detectsCommonLanguagesAndFallsBackToPlainText() {
        for (path, language) in [("script.py", CodeLanguage.python), ("client.jsx", .javascript), ("types.tsx", .typescript),
            ("View.swift", .swift), ("config.json", .json), ("Main.java", .java), ("index.html", .html), ("query.SQL", .sql),
            ("Main.kt", .kotlin), ("code.go", .go), ("program.rs", .rust), ("data.yaml", .yaml), ("unknown.dat", .plain)] {
            #expect(CodeLanguage.detect(path: path) == language)
        }
    }
    @Test func pythonHighlightsUnicodeStringsCommentsAndTripleQuotes() {
        var lexer = CodeLexer(language: .python)
        let line = "def café(x): return \"🍎\" # if 42"
        let spans = lexer.tokens(in: line)
        func text(_ token: SyntaxToken) -> String { (line as NSString).substring(with: token.range) }
        #expect(spans.contains { text($0) == "def" && $0.kind == .keyword })
        #expect(spans.contains { text($0) == "café" && $0.kind == .function })
        #expect(spans.contains { text($0) == "\"🍎\"" && $0.kind == .string })
        #expect(spans.contains { text($0) == "# if 42" && $0.kind == .comment })
        #expect(lexer.tokens(in: "\"\"\"start").first?.kind == .string)
        #expect(lexer.tokens(in: "return is text").first?.kind == .string)
        #expect(lexer.tokens(in: "end\"\"\"; return 10").last?.kind == .number)
    }
    @Test func javascriptTypescriptPreserveMultilineStateAcrossDiffGaps() throws {
        let value = FileComparison(before: "/* begin\nend */ const x = `hello\nworld`;\n", after: "/* begin\ninserted\nend */ const x = `hello\nworld`;\n", beforeLabel: "A", afterLabel: "B",
            patch: "@@ -1,3 +1,4 @@\n /* begin\n+inserted\n end */ const x = `hello\n world`;\n")
        let rows = try DiffAlignment.make(value)
        let syntax = CodeHighlighter.highlight(rows: rows, before: .javascript, after: .typescript)
        #expect(syntax.before[1].isEmpty)
        #expect(syntax.after[1].first?.kind == .comment)
        #expect(syntax.before[2].contains { $0.kind == .keyword })
        #expect(syntax.after[3].contains { $0.kind == .string })
        let plain = CodeHighlighter.highlight(rows: rows, before: .plain, after: .plain)
        #expect(plain.before.allSatisfy { $0.isEmpty }); #expect(plain.after.allSatisfy { $0.isEmpty })
    }
    @MainActor @Test func syntaxUpdatePreservesNativeScrollSelectionAndDiffBackground() throws {
        let text = (1...100).map { "const item\($0) = 42; // comment" }.joined(separator: "\n")
        var changed = text.components(separatedBy: "\n")
        changed[0] = "const item1 = 43; // changed"
        let comparison = FileComparison(before: text, after: changed.joined(separator: "\n"), beforeLabel: "A", afterLabel: "B",
            patch: "@@ -1 +1 @@\n-const item1 = 42; // comment\n+const item1 = 43; // changed\n")
        let rows = try DiffAlignment.make(comparison)
        let container = ParallelDiffContainer()
        container.frame = NSRect(x: 0, y: 0, width: 1100, height: 600)
        container.update(rows); container.layoutSubtreeIfNeeded()
        let scrolls = container.subviews.compactMap { $0 as? NSScrollView }
        let view = try #require(scrolls[0].documentView as? NSTextView)
        view.setSelectedRange(NSRange(location: 15, length: 5))
        scrolls[0].contentView.scroll(to: NSPoint(x: 0, y: 180))
        container.update(rows, syntax: CodeHighlighter.highlight(rows: rows, before: .javascript, after: .typescript))
        #expect(view.selectedRange() == NSRange(location: 15, length: 5))
        #expect(abs(scrolls[0].contentView.bounds.origin.y - 180) < 1)
        #expect(abs(scrolls[1].contentView.bounds.origin.y - 180) < 1)
        #expect(view.textStorage?.attribute(.foregroundColor, at: 12, effectiveRange: nil) as? NSColor == SyntaxKind.keyword.color)
        #expect(view.textStorage?.attribute(.backgroundColor, at: 12, effectiveRange: nil) as? NSColor == NSColor.systemRed.withAlphaComponent(0.13))
        if let path = ProcessInfo.processInfo.environment["EFBY_SYNTAX_PREVIEW_PATH"] {
            scrolls[0].contentView.scroll(to: .zero)
            let bitmap = try #require(container.bitmapImageRepForCachingDisplay(in: container.bounds))
            container.cacheDisplay(in: container.bounds, to: bitmap)
            try #require(bitmap.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: path))
        }
    }
    @MainActor @Test func overlayKeepsRepositoryMountedInSameWindow() async throws {
        let f = try await GitFixture.make(); defer { f.cleanup() }
        let registry = try SQLiteRegistry(path: f.folder.appendingPathComponent("catalog.sqlite").path)
        let service = DeskService(git: f.adapter, registry: registry, cloud: BitbucketClient(vault: KeychainVault()))
        let model = DeskModel(service: service, terminalFactory: { PTYTerminal(shell: "/bin/sh", login: false) })
        let oid = try await f.git(["rev-parse", "HEAD"])
        let file = FileChange(path: Data("script.py".utf8), status: "M")
        model.selectedID = f.repository.id; model.selectedOIDs = [oid]; model.files = [file]
        model.selectedFile = file.id; model.terminalVisible = true; model.branchWidth = 190
        let source = NSWindow(contentRect: NSRect(x: 20, y: 20, width: 1100, height: 700), styleMask: [.titled], backing: .buffered, defer: false)
        source.isReleasedWhenClosed = false
        defer { source.close() }
        let originalFrame = source.frame
        let example = FileComparison(before: "# Calculate a total\ndef total(items):\n    return sum(items)\n", after: "# Calculate a total\ndef total(items):\n    return sum(items) * 2\n", beforeLabel: oid, afterLabel: oid,
            patch: "@@ -1,3 +1,3 @@\n # Calculate a total\n def total(items):\n-    return sum(items)\n+    return sum(items) * 2\n")
        model.comparison = example; model.diffRows = try DiffAlignment.make(example); model.diffAligned = true
        model.diffSyntax = CodeHighlighter.highlight(rows: model.diffRows, before: .python, after: .python)
        let layout = DiffLayout(rows: model.diffRows)
        model.diffBlocks = layout.blocks; model.diffMap = layout.map; model.diffInline = layout.inline
        let probe = NSView()
        let hosting = NSHostingView(rootView: ComparisonWorkspaceLayer(model: model) { WorkspaceRetentionProbe(view: probe) })
        source.appearance = NSAppearance(named: .darkAqua)
        hosting.appearance = source.appearance
        hosting.sizingOptions = []
        source.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        hosting.layoutSubtreeIfNeeded()
        #expect(probe.window === source)
        #expect(!source.styleMask.contains(.fullScreen))
        let windowCount = NSApp.windows.count
        #expect(source.frame == originalFrame)
        if let path = ProcessInfo.processInfo.environment["EFBY_COMPARE_PREVIEW_PATH"], let content = source.contentView {
            content.layoutSubtreeIfNeeded()
            let bitmap = try #require(content.bitmapImageRepForCachingDisplay(in: content.bounds))
            content.cacheDisplay(in: content.bounds, to: bitmap)
            try #require(bitmap.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: path))
        }
        model.closeDiff()
        try await Task.sleep(for: .milliseconds(100))
        hosting.layoutSubtreeIfNeeded()
        #expect(probe.window === source)
        #expect(NSApp.windows.count == windowCount)
        #expect(source.frame == originalFrame)
        #expect(model.selectedFile == nil)
        #expect(model.selectedOIDs == [oid]); #expect(model.selectedID == f.repository.id)
        #expect(model.terminalVisible); #expect(model.branchWidth == 190)
    }
}
