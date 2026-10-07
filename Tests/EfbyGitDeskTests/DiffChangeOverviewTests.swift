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
        let blocks = DiffChangeOverview.make(rows: rows)
        let map = DiffChangeOverview.map(blocks: blocks, rowCount: rows.count)
        #expect(map.count == 240)
        #expect(map.first == true); #expect(map.last == true)
        #expect(map.filter { $0 }.count == 2)
    }
    @Test func emptyAndIdenticalDocumentsHaveNoChanges() {
        #expect(DiffChangeOverview.make(rows: []).isEmpty)
        #expect(DiffChangeOverview.map(blocks: [], rowCount: 0).isEmpty)
        let row = DiffRow(before: "same", after: "same", beforeNumber: 1, afterNumber: 1)
        #expect(DiffChangeOverview.make(rows: [row]).isEmpty)
    }
}
