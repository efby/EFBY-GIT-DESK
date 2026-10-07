import Foundation

struct DiffLayout: Sendable {
    let rows: [DiffRow]
    let blocks: [DiffChangeBlock]
    let map: [Bool]
    init(rows: [DiffRow]) {
        self.rows = rows; blocks = DiffChangeOverview.make(rows: rows)
        map = DiffChangeOverview.map(blocks: blocks, rowCount: rows.count)
    }
}
