import Foundation
import Testing
import AppKit
@testable import EfbyGitDeskPresentation

struct DiffIntralineTests {
    private func marks(_ before: String?, _ after: String?) -> DiffInlineRow {
        DiffIntraline.make(rows: [DiffRow(before: before, after: after, beforeNumber: before == nil ? nil : 1, afterNumber: after == nil ? nil : 1)])[0]
    }
    private func segments(_ text: String, _ ranges: [NSRange]) -> [String] {
        ranges.map { (text as NSString).substring(with: $0) }
    }
    @Test func replacementsAreHighlightedOnBothSidesWithoutSharedText() {
        let a = "const first = 1; const last = 2;", b = "const first = 9; const last = 8;"
        let result = marks(a, b)
        #expect(segments(a, result.before) == ["1", "2"])
        #expect(segments(b, result.after) == ["9", "8"])
        #expect(!result.limited)
    }
    @Test func insertionAndDeletionMarkOnlyTheExistingChangedSide() {
        let a = "return sum(items)", b = "return sum(items) * 2"
        let inserted = marks(a, b)
        #expect(inserted.before.isEmpty)
        #expect(segments(b, inserted.after) == [" * 2"])
        let removed = marks(b, a)
        #expect(segments(b, removed.before) == [" * 2"])
        #expect(removed.after.isEmpty)
        #expect(marks(nil, "added") == DiffInlineRow())
        #expect(!marks("", "added").after.isEmpty) // An existing empty line still changed.
        #expect(segments("deleted", marks("deleted", nil).before) == ["deleted"])
        #expect(marks(nil, "").after.isEmpty)
    }
    @Test func identicalLinesAndFinalNewlineOnlyHaveNoTextMarks() {
        #expect(marks("same", "same") == DiffInlineRow())
        let row = DiffRow(before: "same", after: "same", beforeNumber: 1, afterNumber: 1, differentEnding: true)
        #expect(DiffIntraline.make(rows: [row]) == [DiffInlineRow()])
    }
    @Test func unicodeAndWhitespaceRangesUseUTF16WithoutSplittingCharacters() {
        let a = "👩‍💻 café = 1", b = "👩‍💻 café = 2"
        #expect(segments(a, marks(a, b).before) == ["1"])
        #expect(segments(b, marks(a, b).after) == ["2"])
        let emojiA = "value = 👨‍👩‍👧", emojiB = "value = 👩‍💻"
        #expect(segments(emojiA, marks(emojiA, emojiB).before) == ["👨‍👩‍👧"])
        #expect(segments(emojiB, marks(emojiA, emojiB).after) == ["👩‍💻"])
        #expect(segments("x  y", marks("x y", "x  y").after) == [" "])
    }
    @Test func complexLinesBoundWorkAndKeepCommonEndsUnmarked() {
        let a = "start " + String(repeating: "x", count: 5000) + " end"
        let b = "start " + String(repeating: "y", count: 5000) + " end"
        let value = marks(a, b)
        #expect(value.limited)
        #expect(value.before == [NSRange(location: 6, length: 5000)])
        #expect(value.after == [NSRange(location: 6, length: 5000)])
    }
    @MainActor @Test func nativeTextMarksSurviveSyntaxRefreshWithoutChangingSelection() throws {
        let rows = [DiffRow(before: "const n = 1", after: "const n = 2", beforeNumber: 1, afterNumber: 1),
                    DiffRow(before: "same", after: "same", beforeNumber: 2, afterNumber: 2),
                    DiffRow(before: nil, after: "add", beforeNumber: nil, afterNumber: 3)]
        let container = ParallelDiffContainer()
        container.frame = NSRect(x: 0, y: 0, width: 1100, height: 600)
        container.update(rows); container.layoutSubtreeIfNeeded()
        let views = try container.subviews.compactMap { $0 as? NSScrollView }.map { try #require($0.documentView as? NSTextView) }
        views[0].setSelectedRange(NSRange(location: 12, length: 5))
        container.update(rows, syntax: CodeHighlighter.highlight(rows: rows, before: .javascript, after: .javascript))
        for (index, text) in views.enumerated() {
            let storage = try #require(text.textStorage)
            let changed = (storage.string as NSString).range(of: index == 0 ? "1\n" : "2\n").location
            let color = index == 0 ? NSColor.systemRed : .systemGreen
            #expect(storage.attribute(.backgroundColor, at: changed, effectiveRange: nil) as? NSColor == color.withAlphaComponent(0.48))
            let equal = (storage.string as NSString).range(of: "same").location
            #expect(storage.attribute(.backgroundColor, at: equal, effectiveRange: nil) as? NSColor == .clear)
        }
        let addedStorage = try #require(views[1].textStorage)
        let added = (addedStorage.string as NSString).range(of: "add").location
        #expect(addedStorage.attribute(.backgroundColor, at: added, effectiveRange: nil) as? NSColor == NSColor.systemGreen.withAlphaComponent(0.13))
        let addedPrefix = (addedStorage.string as NSString).range(of: "    3 +").location
        #expect(addedPrefix != NSNotFound)
        #expect(addedStorage.attribute(.backgroundColor, at: addedPrefix, effectiveRange: nil) as? NSColor == NSColor.systemGreen.withAlphaComponent(0.13))
        #expect(views[0].selectedRange() == NSRange(location: 12, length: 5))
    }
}
