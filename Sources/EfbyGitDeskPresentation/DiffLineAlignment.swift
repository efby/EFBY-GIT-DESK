import Foundation
import EfbyGitDeskDomain

/// Exact content anchors preserve order, even when Git chose blank context lines.
enum DiffLineAlignment {
    static func make(_ left: [String], _ right: [String]) throws -> [DiffRow] {
        var matches: [(Int, Int)] = []
        var pending = [(0..<left.count, 0..<right.count)]
        var work = 2_000_000
        while let (originalA, originalB) = pending.popLast() {
            var a = originalA, b = originalB
            while !a.isEmpty && !b.isEmpty && left[a.lowerBound] == right[b.lowerBound] {
                matches.append((a.lowerBound, b.lowerBound))
                a = (a.lowerBound + 1)..<a.upperBound; b = (b.lowerBound + 1)..<b.upperBound
            }
            while !a.isEmpty && !b.isEmpty && left[a.upperBound - 1] == right[b.upperBound - 1] {
                matches.append((a.upperBound - 1, b.upperBound - 1))
                a = a.lowerBound..<(a.upperBound - 1); b = b.lowerBound..<(b.upperBound - 1)
            }
            guard !a.isEmpty && !b.isEmpty else { continue }
            work -= a.count + b.count
            guard work >= 0 else { throw limit() }
            var positionsA: [String: [Int]] = [:], positionsB: [String: [Int]] = [:]
            for i in a where !left[i].trimmingCharacters(in: .whitespaces).isEmpty { positionsA[left[i], default: []].append(i) }
            for j in b where !right[j].trimmingCharacters(in: .whitespaces).isEmpty { positionsB[right[j], default: []].append(j) }
            let candidates = a.compactMap { i -> (Int, Int)? in
                guard positionsA[left[i]]?.count == 1, let other = positionsB[left[i]], other.count == 1 else { return nil }
                return (i, other[0])
            }
            let anchors = increasing(candidates)
            if anchors.isEmpty {
                matches += try exactMatches(left, right, a: a, b: b, work: &work)
            } else {
                var startA = a.lowerBound, startB = b.lowerBound
                for (i, j) in anchors {
                    pending.append((startA..<i, startB..<j)); matches.append((i, j))
                    startA = i + 1; startB = j + 1
                }
                pending.append((startA..<a.upperBound, startB..<b.upperBound))
            }
        }
        matches.sort { $0.0 < $1.0 }
        var rows: [DiffRow] = [], a = 0, b = 0
        func gap(to endA: Int, _ endB: Int) {
            while a < endA || b < endB {
                let takeA = a < endA, takeB = b < endB
                rows.append(DiffRow(before: takeA ? left[a] : nil, after: takeB ? right[b] : nil,
                                    beforeNumber: takeA ? a + 1 : nil, afterNumber: takeB ? b + 1 : nil))
                if takeA { a += 1 }; if takeB { b += 1 }
            }
        }
        for (i, j) in matches {
            gap(to: i, j)
            rows.append(DiffRow(before: left[i], after: right[j], beforeNumber: i + 1, afterNumber: j + 1))
            a = i + 1; b = j + 1
        }
        gap(to: left.count, right.count)
        return rows
    }
    private static func increasing(_ pairs: [(Int, Int)]) -> [(Int, Int)] {
        guard !pairs.isEmpty else { return [] }
        var tails: [Int] = [], previous = Array(repeating: -1, count: pairs.count)
        for index in pairs.indices {
            var low = 0, high = tails.count
            while low < high {
                let middle = (low + high) / 2
                if pairs[tails[middle]].1 < pairs[index].1 { low = middle + 1 } else { high = middle }
            }
            if low > 0 { previous[index] = tails[low - 1] }
            if low == tails.count { tails.append(index) } else { tails[low] = index }
        }
        var result: [(Int, Int)] = [], cursor = tails.last!
        while cursor >= 0 { result.append(pairs[cursor]); cursor = previous[cursor] }
        return result.reversed()
    }
    /// Bounded Myers matching handles repeated lines without a quadratic matrix.
    private static func exactMatches(_ left: [String], _ right: [String], a: Range<Int>, b: Range<Int>, work: inout Int) throws -> [(Int, Int)] {
        // No common content: these are genuine replacement/one-sided blocks.
        let common = Set(a.map { left[$0] }).intersection(b.map { right[$0] })
        if common.isEmpty { return [] }
        var frontier = [1: 0], trace: [[Int: Int]] = [], entries = 0
        for distance in 0...(a.count + b.count) {
            entries += frontier.count
            guard entries <= 250_000 else { throw limit() }
            trace.append(frontier)
            for diagonal in stride(from: -distance, through: distance, by: 2) {
                work -= 1
                guard work >= 0 else { throw limit() }
                var x: Int
                if diagonal == -distance || (diagonal != distance && frontier[diagonal - 1, default: -1] < frontier[diagonal + 1, default: -1]) {
                    x = frontier[diagonal + 1, default: 0]
                } else { x = frontier[diagonal - 1, default: 0] + 1 }
                var y = x - diagonal
                while x < a.count && y < b.count && x >= 0 && y >= 0 && left[a.lowerBound + x] == right[b.lowerBound + y] {
                    work -= 1
                    guard work >= 0 else { throw limit() }
                    x += 1; y += 1
                }
                frontier[diagonal] = x
                if x >= a.count && y >= b.count {
                    var result: [(Int, Int)] = []
                    for d in stride(from: distance, through: 0, by: -1) {
                        let v = trace[d], k = x - y
                        let previousK = k == -d || (k != d && v[k - 1, default: -1] < v[k + 1, default: -1]) ? k + 1 : k - 1
                        let previousX = v[previousK, default: 0], previousY = previousX - previousK
                        while x > previousX && y > previousY {
                            x -= 1; y -= 1
                            result.append((a.lowerBound + x, b.lowerBound + y))
                        }
                        x = previousX; y = previousY
                    }
                    return result.reversed()
                }
            }
        }
        throw limit()
    }
    private static func limit() -> DeskError {
        DeskError("La realineación supera el límite de complejidad. Se muestra el diff original de Git sin emparejar líneas por posición.")
    }
}
