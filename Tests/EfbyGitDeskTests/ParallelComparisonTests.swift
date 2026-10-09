import Foundation
import Testing
import AppKit
import EfbyGitDeskDomain
import EfbyGitDeskApplication
import EfbyGitDeskInfrastructure
@testable import EfbyGitDeskPresentation

struct ParallelComparisonTests {
    @Test func completeDocumentsAlignSeparatedHunksAndUnequalBlocks() async throws {
        let f = try await GitFixture.make(); defer { f.cleanup() }
        let before = (1...35).map { "line \($0)" }.joined(separator: "\n") + "\n"
        let base = try await f.commit("compare.txt", before, message: "Before")
        var lines = before.components(separatedBy: "\n"); lines.removeLast()
        lines.replaceSubrange(2..<4, with: ["replacement", "inserted", "extra"])
        lines.remove(at: 28)
        let after = lines.joined(separator: "\n") + "\n"
        let target = try await f.commit("compare.txt", after, message: "After")
        let context = DiffContext.commits(try ComparisonPair(base: base, target: target))
        let file = try #require(try await f.adapter.changes(f.repository, context: context).first)
        // Custom diff formatting must not break our hunk parser.
        _ = try await f.git(["config", "diff.suppressBlankEmpty", "true"])
        let comparison = try await f.adapter.fileComparison(f.repository, context: context, file: file)
        #expect(comparison.before == before); #expect(comparison.after == after)
        let rows = try DiffAlignment.make(comparison)
        #expect(rows.compactMap(\.before).joined(separator: "\n") + "\n" == before)
        #expect(rows.compactMap(\.after).joined(separator: "\n") + "\n" == after)
        #expect(rows.contains { $0.before == "line 3" && $0.after == "replacement" && $0.changed })
        #expect(rows.contains { $0.before == nil && $0.after == "extra" })
        #expect(rows.first?.beforeNumber == 1)
        #expect(rows.last?.beforeNumber == 35)
        #expect(rows.last?.afterNumber == 35)
    }

    @Test func renameRootBinaryAndLocalVersionsAreRepresented() async throws {
        let f = try await GitFixture.make(); defer { f.cleanup() }
        let root = try await f.git(["rev-parse", "HEAD"])
        let rootFile = try #require(try await f.adapter.changes(f.repository, context: .commit(root, parent: 0)).first)
        let initial = try await f.adapter.fileComparison(f.repository, context: .commit(root, parent: 0), file: rootFile)
        #expect(initial.before == ""); #expect(initial.after == "base\n")
        #expect(try DiffAlignment.make(initial).first?.before == nil)
        _ = try await f.git(["mv", "README.md", "renamed\nname.md"])
        _ = try await f.git(["commit", "-m", "Rename"])
        let target = try await f.git(["rev-parse", "HEAD"])
        let pair = DiffContext.commits(try ComparisonPair(base: root, target: target))
        let rename = try #require(try await f.adapter.changes(f.repository, context: pair).first)
        let renamed = try await f.adapter.fileComparison(f.repository, context: pair, file: rename)
        #expect(renamed.before == "base\n"); #expect(renamed.after == "base\n")
        #expect(try DiffAlignment.make(renamed).count == 1)

        try f.write("renamed\nname.md", "staged\n")
        _ = try await f.git(["add", "--", "renamed\nname.md"])
        let stagedFile = try #require(try await f.adapter.changes(f.repository, context: .staged).first)
        let staged = try await f.adapter.fileComparison(f.repository, context: .staged, file: stagedFile)
        #expect(staged.before == "base\n"); #expect(staged.after == "staged\n")
        try f.write("renamed\nname.md", "working")
        let workingFile = try #require(try await f.adapter.changes(f.repository, context: .working).first)
        let working = try await f.adapter.fileComparison(f.repository, context: .working, file: workingFile)
        #expect(working.before == "staged\n"); #expect(working.after == "working")
        #expect(try DiffAlignment.make(working).first?.after == "working")
        try Data([0, 1, 0, 2]).write(to: f.folder.appendingPathComponent("binary.dat"))
        _ = try await f.git(["add", "--", "binary.dat"])
        let binary = try #require(try await f.adapter.changes(f.repository, context: .staged).first { $0.name == "binary.dat" })
        let summary = try await f.adapter.fileComparison(f.repository, context: .staged, file: binary)
        #expect(summary.after == nil); #expect(!summary.notice.isEmpty)
    }

    @MainActor @Test func clickOrderDoesNotReverseLowerToUpperComparison() async throws {
        let f = try await GitFixture.make(); defer { f.cleanup() }
        let root = try await f.git(["rev-parse", "HEAD"])
        let head = try await f.commit("README.md", "new\n", message: "Upper")
        let registry = try SQLiteRegistry(path: f.folder.appendingPathComponent("catalog.sqlite").path)
        let service = DeskService(git: f.adapter, registry: registry, cloud: BitbucketClient(vault: KeychainVault()))
        let model = DeskModel(service: service, terminalFactory: { PTYTerminal(shell: "/bin/sh", login: false) })
        model.commits = try await f.adapter.history(f.repository, tips: [head], offset: 0, search: "")
        model.chooseCommit(model.commits[0]); model.chooseCommit(model.commits[1])
        #expect(model.context == .commits(try ComparisonPair(base: root, target: head)))
        model.selectedOIDs = []; model.chooseCommit(model.commits[1]); model.chooseCommit(model.commits[0])
        #expect(model.context == .commits(try ComparisonPair(base: root, target: head)))
    }

    @Test func alignmentHandlesEmptyLinesNoFinalNewlineAndLimits() throws {
        let value = FileComparison(before: "a\n\nb", after: "a\n\nc", beforeLabel: "A", afterLabel: "B",
            patch: "@@ -1,3 +1,3 @@\n a\n \n-b\n\\ No newline at end of file\n+c\n\\ No newline at end of file\n")
        let rows = try DiffAlignment.make(value)
        #expect(rows.count == 3); #expect(rows[1].before == "")
        #expect(rows[2].before == "b"); #expect(rows[2].after == "c")
        let crlf = FileComparison(before: "a\r\nb\r\n", after: "a\r\nc\r\n", beforeLabel: "A", afterLabel: "B",
            patch: "@@ -1,2 +1,2 @@\n a\r\n-b\r\n+c\r\n")
        #expect(try DiffAlignment.make(crlf).count == 2)
        let ending = FileComparison(before: "same\n", after: "same", beforeLabel: "A", afterLabel: "B",
            patch: "@@ -1 +1 @@\n-same\n+same\n\\ No newline at end of file\n")
        #expect(try DiffAlignment.make(ending).first?.changed == true)
        #expect(throws: DeskError.self) {
            try DiffAlignment.make(FileComparison(before: "changed outside Git\n", after: value.after,
                beforeLabel: "A", afterLabel: "B", patch: value.patch))
        }
        let huge = String(repeating: "line\n", count: 50_001)
        #expect(throws: DeskError.self) {
            try DiffAlignment.make(FileComparison(before: huge, after: "", beforeLabel: "A", afterLabel: "B", patch: ""))
        }
    }

    @MainActor @Test func crlfTerminatorsStayInComparisonButNotInEitherEditor() throws {
        let comparison = FileComparison(before: "same\r\nold\r\n", after: "same\r\nnew\r\n",
            beforeLabel: "A", afterLabel: "B", patch: "@@ -1,2 +1,2 @@\n same\r\n-old\r\n+new\r\n")
        let rows = try DiffAlignment.make(comparison)
        #expect(rows[0].before == "same\r")
        #expect(rows[0].after == "same\r")
        let container = ParallelDiffContainer()
        container.update(rows)
        let editors = container.subviews.compactMap { ($0 as? NSScrollView)?.documentView as? NSTextView }
        #expect(editors.count == 2)
        #expect(editors[0].string.contains("same\n"))
        #expect(editors[1].string.contains("same\n"))
        #expect(editors[0].string.contains("old\n"))
        #expect(editors[1].string.contains("new\n"))
        #expect(editors.allSatisfy { !$0.string.contains("\r") && !$0.string.contains("␍") })

        let unchanged = FileComparison(before: "same\r\nblank\r\n", after: "same\r\nblank\r\n",
            beforeLabel: "A", afterLabel: "B", patch: "")
        let unchangedRows = try DiffAlignment.make(unchanged)
        #expect(unchangedRows.allSatisfy { !$0.changed })
        container.update(unchangedRows)
        #expect(editors.allSatisfy { $0.string.contains("blank\n") && !$0.string.contains("␍") })
    }

    @MainActor @Test func nativeColumnsSynchronizeBothAxesAndNavigateChanges() throws {
        let lines = (1...100).map { "line \($0)" }.joined(separator: "\n")
        var changed = lines.components(separatedBy: "\n")
        changed[2] = "modified line 3"; changed.insert("inserted line", at: 3)
        let comparison = FileComparison(before: lines, after: changed.joined(separator: "\n"), beforeLabel: "A", afterLabel: "B",
            patch: "@@ -1,6 +1,7 @@\n line 1\n line 2\n-line 3\n+modified line 3\n+inserted line\n line 4\n line 5\n line 6\n")
        let container = ParallelDiffContainer()
        container.frame = NSRect(x: 0, y: 0, width: 900, height: 500)
        var rows = try DiffAlignment.make(comparison)
        rows[0] = DiffRow(before: String(repeating: "long", count: 150), after: "short", beforeNumber: 1, afterNumber: 1)
        container.update(rows)
        container.layoutSubtreeIfNeeded()
        let scrolls = container.subviews.compactMap { $0 as? NSScrollView }
        #expect(scrolls.count == 2)
        #expect(abs(scrolls[0].frame.width - scrolls[1].frame.width) < 1)
        scrolls[0].contentView.scroll(to: NSPoint(x: 200, y: 180))
        #expect(abs(scrolls[0].contentView.bounds.origin.y - scrolls[1].contentView.bounds.origin.y) < 1)
        #expect(abs(scrolls[1].contentView.bounds.origin.x - 200) < 1)
        scrolls[1].contentView.scroll(to: NSPoint(x: 400, y: 360))
        #expect(abs(scrolls[0].contentView.bounds.origin.y - scrolls[1].contentView.bounds.origin.y) < 1)
        #expect(abs(scrolls[0].contentView.bounds.origin.x - 400) < 1)
        #expect(abs(scrolls[0].contentView.bounds.origin.x - scrolls[1].contentView.bounds.origin.x) < 1)
        #expect(scrolls[0].documentView?.frame.width == scrolls[1].documentView?.frame.width)
        let jump = DiffJumpTarget(row: 35)
        container.jump(to: jump)
        #expect(abs(scrolls[0].contentView.bounds.origin.y - 630) < 1)
        #expect(abs(scrolls[1].contentView.bounds.origin.y - 630) < 1)
        #expect(abs(scrolls[1].contentView.bounds.origin.x - 400) < 1)
        scrolls[1].contentView.scroll(to: .zero)
        container.jump(to: jump) // Updating an unchanged target must preserve manual scrolling.
        #expect(scrolls[0].contentView.bounds.origin == .zero)
        container.jump(to: DiffJumpTarget(row: 35))
        #expect(abs(scrolls[1].contentView.bounds.origin.y - 630) < 1)
        container.jump(to: DiffJumpTarget(row: 10, restoreOffset: CGPoint(x: 80, y: 180)))
        #expect(abs(scrolls[0].contentView.bounds.origin.y - 180) < 1)
        #expect(abs(scrolls[0].contentView.bounds.origin.x - 80) < 1)
        #expect(abs(scrolls[1].contentView.bounds.origin.y - 180) < 1)
        if let path = ProcessInfo.processInfo.environment["EFBY_DIFF_PREVIEW_PATH"] {
            let window = NSWindow(contentRect: container.frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            defer { window.close() }
            window.contentView = container
            scrolls[0].contentView.scroll(to: .zero)
            container.layoutSubtreeIfNeeded()
            let bitmap = try #require(container.bitmapImageRepForCachingDisplay(in: container.bounds))
            container.cacheDisplay(in: container.bounds, to: bitmap)
            let data = try #require(bitmap.representation(using: .png, properties: [:]))
            try data.write(to: URL(fileURLWithPath: path))
        }
    }
    @MainActor @Test func bothVerticalTracksShowChangeMapAndReportDistanceWhileScrolling() throws {
        let rows = (0..<200).map { number in
            DiffRow(before: "line \(number)", after: number == 150 ? "added replacement" : "line \(number)", beforeNumber: number + 1, afterNumber: number + 1)
        }
        let container = ParallelDiffContainer()
        container.frame = NSRect(x: 0, y: 0, width: 1000, height: 400)
        var status: DiffViewportStatus?
        container.onViewportChange = { status = $0 }
        container.update(rows); container.layoutSubtreeIfNeeded()
        let scrolls = container.subviews.compactMap { $0 as? NSScrollView }
        let left = try #require(scrolls[0].verticalScroller as? DiffOverviewScroller)
        let right = try #require(scrolls[1].verticalScroller as? DiffOverviewScroller)
        #expect(left.marks == right.marks)
        #expect(left.marks.contains { $0.removed && $0.added })
        #expect(left.frame.height > left.frame.width)
        #expect(scrolls.allSatisfy { $0.scrollerStyle == .legacy && !$0.autohidesScrollers })
        let initial = try #require(status?.linesToNext)
        scrolls[0].contentView.scroll(to: NSPoint(x: 0, y: 180))
        let second = try #require(status?.linesToNext)
        #expect(second == initial - 10)
        scrolls[1].contentView.scroll(to: NSPoint(x: 0, y: 360))
        #expect(status?.linesToNext == initial - 20)
        container.jump(to: DiffJumpTarget(row: 150))
        #expect(status?.visibleChange == true)
        #expect(status?.linesToNext == nil)
        scrolls[0].contentView.scroll(to: NSPoint(x: 0, y: 3400))
        #expect(status?.visibleChange == false)
        container.update(Array(rows.prefix(3))); container.layoutSubtreeIfNeeded()
        #expect((scrolls[0].documentView?.frame.height ?? 0) < scrolls[0].contentView.bounds.height)
        #expect(left.knobProportion == 1)
    }

}
