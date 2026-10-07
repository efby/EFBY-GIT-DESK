import Testing
@testable import EfbyGitDeskPresentation

struct DiffChangeOverviewTests {
    @Test func groupsAdjacentChangesAndCountsUnchangedGaps() {
        let rows = (1...12).map { number in
            DiffRow(before: "old", after: [3, 4, 9].contains(number) ? "new" : "old", beforeNumber: number, afterNumber: number)
        }
        let blocks = DiffChangeOverview.make(rows: rows)
        #expect(blocks.count == 2)
        #expect(blocks[0].beforeLines == 3...4)
        #expect(blocks[0].afterLines == 3...4)
        #expect(blocks[0].gapLines == 2)
        #expect(blocks[1].gapLines == 4)
        #expect(blocks[1].firstRow == 8)
    }
    @Test func representsInsertionsDeletionsAndFinalNewlineChanges() {
        let rows = [DiffRow(before: nil, after: "add", beforeNumber: nil, afterNumber: 1),
                    DiffRow(before: "same", after: "same", beforeNumber: 1, afterNumber: 2),
                    DiffRow(before: "delete", after: nil, beforeNumber: 2, afterNumber: nil),
                    DiffRow(before: "same", after: "same", beforeNumber: 3, afterNumber: 3, differentEnding: true)]
        let blocks = DiffChangeOverview.make(rows: rows)
        #expect(blocks[0].beforeLines == nil)
        #expect(blocks[0].afterLines == 1...1)
        #expect(blocks[1].beforeLines == 2...3)
        #expect(blocks[1].afterLines == 3...3)
        #expect(blocks[1].gapLines == 1)
    }
    @Test func mapRemainsBoundedAndMarksBeginningAndEnd() {
        let rows = (1...50_000).map { number in
            DiffRow(before: "old", after: number == 1 || number == 50_000 ? "new" : "old", beforeNumber: number, afterNumber: number)
        }
        let map = DiffChangeOverview.coloredMap(rows: rows)
        #expect(map.count == 240)
        #expect(map.first?.removed == true); #expect(map.last?.added == true)
        #expect(map.filter { $0.removed || $0.added }.count == 2)
    }
    @Test func emptyAndIdenticalDocumentsHaveNoChanges() {
        #expect(DiffChangeOverview.make(rows: []).isEmpty)
        #expect(DiffChangeOverview.coloredMap(rows: []).isEmpty)
        let row = DiffRow(before: "same", after: "same", beforeNumber: 1, afterNumber: 1)
        #expect(DiffChangeOverview.make(rows: [row]).isEmpty)
    }
    @Test func verticalMapDistinguishesRemovedAddedAndReplacedLines() {
        let rows = [DiffRow(before: "deleted", after: nil, beforeNumber: 1, afterNumber: nil),
                    DiffRow(before: nil, after: "added", beforeNumber: nil, afterNumber: 1),
                    DiffRow(before: "old", after: "new", beforeNumber: 2, afterNumber: 2),
                    DiffRow(before: "same", after: "same", beforeNumber: 3, afterNumber: 3)]
        let map = DiffChangeOverview.coloredMap(rows: rows, bucketCount: 4)
        #expect(map[0].removed && !map[0].added)
        #expect(map[1].added && !map[1].removed)
        #expect(map[2].removed && map[2].added)
        #expect(!map[3].removed && !map[3].added)
        #expect(DiffChangeOverview.coloredMap(rows: []).isEmpty)
    }
    @Test func remainingDistanceTracksVisibleEdgeAndHandlesEndOfChanges() {
        let rows = (0..<100).map { number in
            DiffRow(before: "old", after: number == 70 ? "new" : "old", beforeNumber: number + 1, afterNumber: number + 1)
        }
        let blocks = DiffChangeOverview.make(rows: rows)
        #expect(DiffViewportStatus.make(firstRow: 0, lastRow: 20, blocks: blocks).linesToNext == 50)
        #expect(DiffViewportStatus.make(firstRow: 10, lastRow: 30, blocks: blocks).linesToNext == 40)
        let visible = DiffViewportStatus.make(firstRow: 65, lastRow: 75, blocks: blocks)
        #expect(visible.visibleChange); #expect(visible.linesToNext == nil)
        let past = DiffViewportStatus.make(firstRow: 80, lastRow: 99, blocks: blocks)
        #expect(!past.visibleChange); #expect(past.linesToNext == nil)
        #expect(DiffViewportStatus.make(firstRow: 0, lastRow: 69, blocks: blocks).message.contains("Falta 1 línea"))
    }

}
