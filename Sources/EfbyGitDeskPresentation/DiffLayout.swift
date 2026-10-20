import Foundation

struct DiffLayout: Sendable {
    let rows: [DiffRow]
    let blocks: [DiffChangeBlock]
    let inline: [DiffInlineRow]
    let map: [DiffMapMark]
    let lineEndingCount: Int
    init(rows: [DiffRow]) {
        self.rows = rows; blocks = DiffChangeOverview.make(rows: rows)
        map = DiffChangeOverview.coloredMap(rows: rows)
        inline = DiffIntraline.make(rows: rows)
        lineEndingCount = rows.count(where: \.lineEndingChanged)
    }
}
