import Foundation

public enum DiffIntraline {
    /// UTF-16 ranges for AppKit, without splitting Unicode grapheme clusters.
    public static func make(rows: [DiffRow]) -> [DiffInlineRow] {
        var budget = 2_000_000
        return rows.map { row in
            guard row.before != row.after else { return DiffInlineRow() }
            guard let before = row.before else {
                return DiffInlineRow(after: fullRange(row.after))
            }
            guard let after = row.after else {
                return DiffInlineRow(before: fullRange(before))
            }
            if before.isEmpty { return DiffInlineRow(after: fullRange(after)) }
            if after.isEmpty { return DiffInlineRow(before: fullRange(before)) }
            let a = Array(before), b = Array(after)
            var prefix = 0
            while prefix < min(a.count, b.count) && a[prefix] == b[prefix] { prefix += 1 }
            var endA = a.count, endB = b.count
            while endA > prefix && endB > prefix && a[endA - 1] == b[endB - 1] { endA -= 1; endB -= 1 }
            let startA = a[..<prefix].reduce(0) { $0 + String($1).utf16.count }
            let startB = b[..<prefix].reduce(0) { $0 + String($1).utf16.count }
            let left = Array(a[prefix..<endA]), right = Array(b[prefix..<endB])
            // Avoid quadratic work on long, unrelated lines or very large files.
            let cost = left.count * right.count
            guard max(left.count, right.count) <= 4096 && cost <= min(250_000, budget) else {
                return DiffInlineRow(before: range(left, start: startA), after: range(right, start: startB), limited: true)
            }
            budget -= cost
            var removed = Array(repeating: false, count: left.count)
            var added = Array(repeating: false, count: right.count)
            for change in right.difference(from: left) {
                switch change {
                case .remove(let offset, _, _): removed[offset] = true
                case .insert(let offset, _, _): added[offset] = true
                }
            }
            return DiffInlineRow(before: ranges(left, changed: removed, start: startA),
                                 after: ranges(right, changed: added, start: startB))
        }
    }
    private static func fullRange(_ value: String?) -> [NSRange] {
        guard let value, !value.isEmpty else { return [] }
        return [NSRange(location: 0, length: value.utf16.count)]
    }
    private static func range(_ value: [Character], start: Int) -> [NSRange] {
        let length = value.reduce(0) { $0 + String($1).utf16.count }
        return length == 0 ? [] : [NSRange(location: start, length: length)]
    }
    private static func ranges(_ value: [Character], changed: [Bool], start: Int) -> [NSRange] {
        var result: [NSRange] = [], position = start
        for (index, character) in value.enumerated() {
            let length = String(character).utf16.count
            if changed[index] {
                if let last = result.last, NSMaxRange(last) == position {
                    result[result.count - 1].length += length
                } else { result.append(NSRange(location: position, length: length)) }
            }
            position += length
        }
        return result
    }
}
