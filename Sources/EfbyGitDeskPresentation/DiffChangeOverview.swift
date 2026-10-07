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
    public static func coloredMap(rows: [DiffRow], bucketCount: Int = 240) -> [DiffMapMark] {
        guard !rows.isEmpty, bucketCount > 0 else { return [] }
        var result = Array(repeating: DiffMapMark(), count: bucketCount)
        for (index, row) in rows.enumerated() where row.changed {
            let bucket = min(bucketCount - 1, index * bucketCount / rows.count)
            if row.before != nil { result[bucket].removed = true }
            if row.after != nil { result[bucket].added = true }
        }
        return result
    }

}
