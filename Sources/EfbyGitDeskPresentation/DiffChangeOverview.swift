import Foundation

public enum DiffChangeOverview {
    public static func make(rows: [DiffRow]) -> [DiffChangeBlock] {
        var blocks: [DiffChangeBlock] = [], index = 0, previousEnd = -1
        while index < rows.count {
            guard rows[index].changed else { index += 1; continue }
            let start = index
            var beforeStart: Int?, beforeEnd: Int?, afterStart: Int?, afterEnd: Int?
            while index < rows.count && rows[index].changed {
                if let line = rows[index].beforeNumber { if beforeStart == nil { beforeStart = line }; beforeEnd = line }
                if let line = rows[index].afterNumber { if afterStart == nil { afterStart = line }; afterEnd = line }
                index += 1
            }
            blocks.append(DiffChangeBlock(firstRow: start, lastRow: index - 1,
                beforeLines: beforeStart.flatMap { first in beforeEnd.map { first...$0 } },
                afterLines: afterStart.flatMap { first in afterEnd.map { first...$0 } },
                gapLines: start - previousEnd - 1))
            previousEnd = index - 1
        }
        return blocks
    }
    public static func map(blocks: [DiffChangeBlock], rowCount: Int, bucketCount: Int = 240) -> [Bool] {
        guard rowCount > 0, bucketCount > 0 else { return [] }
        var result = Array(repeating: false, count: bucketCount)
        for block in blocks {
            let first = min(bucketCount - 1, block.firstRow * bucketCount / rowCount)
            let last = min(bucketCount - 1, block.lastRow * bucketCount / rowCount)
            for index in first...last { result[index] = true }
        }
        return result
    }
}
