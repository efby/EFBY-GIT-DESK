import Foundation
import Testing
import AppKit
import EfbyGitDeskDomain
@testable import EfbyGitDeskPresentation

struct ShiftedLineAlignmentTests {
    private let before = ["if ambiente == \"DE\":", "    print(event)", "", "    company = \"COPEC\"", "", "if ambiente == \"QA\":", "", "    company = \"QACOPEC\"", "", "if ambiente == \"PR\":", "", "    company = \"COPEC\"", "", "# end"]
    private var after: [String] {
        ["if ambiente == \"DE\":", "    print(event)", "", "    company = \"COPEC\"", "    bucket = \"de\"", "", "if ambiente == \"QA\":", "", "    company = \"QACOPEC\"", "    bucket = \"qa\"", "", "if ambiente == \"PR\":", "", "    company = \"COPEC\"", "    bucket = \"pr\"", "", "# end"]
    }
    @Test func insertedContentKeepsShiftedIfStatementsUnmarkedInBothDirections() throws {
        for (a, b) in [(before, after), (after, before)] {
            let patch = "@@ -1,\(a.count) +1,\(b.count) @@\n" + a.map { "-" + $0 }.joined(separator: "\n") + "\n" + b.map { "+" + $0 }.joined(separator: "\n") + "\n"
            let comparison = FileComparison(before: a.joined(separator: "\n") + "\n", after: b.joined(separator: "\n") + "\n", beforeLabel: "A", afterLabel: "B", patch: patch)
            let rows = try DiffAlignment.make(comparison)
            #expect(rows.compactMap(\.before) == a)
            #expect(rows.compactMap(\.after) == b)
            for text in before.filter({ $0.hasPrefix("if ") }) {
                let row = try #require(rows.first { $0.before == text })
                #expect(row.after == text && !row.changed)
            }
            let buckets = rows.filter { ($0.before ?? $0.after ?? "").contains("bucket") }
            #expect(buckets.count == 3)
            #expect(buckets.allSatisfy { $0.before == nil || $0.after == nil })
            #expect(DiffIntraline.make(rows: rows).enumerated().filter { rows[$0.offset].before?.hasPrefix("if ") == true }.allSatisfy { $0.element == DiffInlineRow() })
        }
    }
    @MainActor @Test func realGitBlankContextDoesNotMarkDisplacedConditions() async throws {
        let fixture = try await GitFixture.make(); defer { fixture.cleanup() }
        let base = try await fixture.commit("shifted.py", before.joined(separator: "\n") + "\n", message: "Before")
        let target = try await fixture.commit("shifted.py", after.joined(separator: "\n") + "\n", message: "Inserted buckets")
        let context = DiffContext.commits(try ComparisonPair(base: base, target: target))
        let file = try #require(try await fixture.adapter.changes(fixture.repository, context: context).first)
        let comparison = try await fixture.adapter.fileComparison(fixture.repository, context: context, file: file)
        let rows = try DiffAlignment.make(comparison)
        #expect(rows.filter { $0.changed }.count == 3)
        #expect(rows.filter { $0.before?.hasPrefix("if ") == true }.allSatisfy { !$0.changed })
        if let path = ProcessInfo.processInfo.environment["EFBY_SHIFTED_LINES_PREVIEW_PATH"] {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1280, height: 500), styleMask: .borderless, backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false; defer { window.close() }
            let native = ParallelDiffContainer(); window.contentView = native
            native.update(rows, syntax: CodeHighlighter.highlight(rows: rows, before: .python, after: .python))
            native.layoutSubtreeIfNeeded(); native.displayIfNeeded()
            let bitmap = try #require(native.bitmapImageRepForCachingDisplay(in: native.bounds))
            native.cacheDisplay(in: native.bounds, to: bitmap)
            try #require(bitmap.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: path))
        }
    }
    @Test func repeatedLinesAndLargeLowEditDistanceRemainAligned() throws {
        let left = (0..<3000).map { $0 % 2 == 0 ? "repeat A" : "repeat B" }
        let right = Array(left.dropFirst()) + ["repeat A"]
        let rows = try DiffLineAlignment.make(left, right)
        #expect(rows.filter { !$0.changed }.count == 2999)
        #expect(rows.compactMap(\.before) == left)
        #expect(rows.compactMap(\.after) == right)
    }
    @Test func crossingBlocksNeverReorderEitherDocument() throws {
        let left = ["start", "if one:", "    first()", "if two:", "    second()", "end"]
        let right = ["start", "if two:", "    second()", "if one:", "    first()", "end"]
        let rows = try DiffLineAlignment.make(left, right)
        #expect(rows.compactMap(\.before) == left)
        #expect(rows.compactMap(\.after) == right)
        #expect(rows.contains { $0.changed })
        #expect(rows.compactMap(\.beforeNumber) == Array(1...left.count))
        #expect(rows.compactMap(\.afterNumber) == Array(1...right.count))
    }
    @Test func complexityLimitReportsOriginalDiffRatherThanFalsePairing() {
        let a = Array(repeating: "A", count: 1500) + Array(repeating: "B", count: 1500)
        let b = Array(repeating: "B", count: 1500) + Array(repeating: "A", count: 1500)
        #expect(throws: DeskError.self) { try DiffLineAlignment.make(a, b) }
    }
    @Test func exhaustiveSmallSequencesPreserveEveryLineAndNumber() throws {
        let alphabet = ["", "if a:", "return"]
        var sequences: [[String]] = [[]]
        for _ in 0..<3 { sequences += sequences.filter { $0.count == sequences.map(\.count).max() }.flatMap { prefix in alphabet.map { prefix + [$0] } } }
        for a in sequences {
            for b in sequences {
                let rows = try DiffLineAlignment.make(a, b)
                #expect(rows.compactMap(\.before) == a)
                #expect(rows.compactMap(\.after) == b)
                #expect(rows.compactMap(\.beforeNumber) == Array(a.indices.map { $0 + 1 }))
                #expect(rows.compactMap(\.afterNumber) == Array(b.indices.map { $0 + 1 }))
            }
        }
    }
}
