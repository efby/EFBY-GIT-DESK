import Foundation
import EfbyGitDeskDomain

/// Validate Git hunks, then realign full documents by exact content off the UI thread.
public enum DiffAlignment {
    public static func make(_ comparison: FileComparison) throws -> [DiffRow] {
        guard let before = comparison.before, let after = comparison.after,
              !comparison.patch.contains("[Diff truncado") else { return [] }
        let left = lines(before), right = lines(after)
        guard left.count + right.count <= 50_000 else {
            throw DeskError("El archivo supera 50.000 líneas entre ambas versiones. El resumen de Git sigue disponible.")
        }
        let pattern = try NSRegularExpression(pattern: #"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@"#)
        let patchLines = comparison.patch.components(separatedBy: "\n")
        var rows: [DiffRow] = []
        var a = 0, b = 0, removed = 0, added = 0, remainingA = 0, remainingB = 0
        func append(_ takeLeft: Bool, _ takeRight: Bool) throws {
            guard (!takeLeft || a < left.count), (!takeRight || b < right.count) else {
                throw DeskError("Los documentos cambiaron durante la lectura. Actualiza para volver a comparar.")
            }
            rows.append(DiffRow(before: takeLeft ? left[a] : nil, after: takeRight ? right[b] : nil,
                                beforeNumber: takeLeft ? a + 1 : nil, afterNumber: takeRight ? b + 1 : nil))
            if takeLeft { a += 1 }; if takeRight { b += 1 }
        }
        func flush() throws {
            for index in 0..<max(removed, added) { try append(index < removed, index < added) }
            removed = 0; added = 0
        }
        for line in patchLines {
            if let match = pattern.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                try flush()
                func number(_ index: Int, default fallback: Int) -> Int {
                    guard let range = Range(match.range(at: index), in: line) else { return fallback }
                    return Int(line[range]) ?? fallback
                }
                remainingA = number(2, default: 1); remainingB = number(4, default: 1)
                let startA = number(1, default: 0) - (remainingA == 0 ? 0 : 1)
                let startB = number(3, default: 0) - (remainingB == 0 ? 0 : 1)
                guard startA >= a, startB >= b, startA <= left.count, startB <= right.count else {
                    throw DeskError("Git no proporcionó una alineación completa. Se conserva el diff original.")
                }
                while a < startA || b < startB { try append(a < startA, b < startB) }
            } else if remainingA > 0 || remainingB > 0 {
                switch line.first {
                case "-":
                    guard a + removed < left.count, left[a + removed] == String(line.dropFirst()) else {
                        throw DeskError("El contenido cambió durante la comparación. Actualiza el archivo.")
                    }
                    removed += 1; remainingA -= 1
                case "+":
                    guard b + added < right.count, right[b + added] == String(line.dropFirst()) else {
                        throw DeskError("El contenido cambió durante la comparación. Actualiza el archivo.")
                    }
                    added += 1; remainingB -= 1
                case " ":
                    try flush()
                    guard a < left.count, b < right.count, left[a] == right[b], left[a] == String(line.dropFirst()) else {
                        throw DeskError("El contenido cambió durante la comparación. Actualiza el archivo.")
                    }
                    try append(true, true); remainingA -= 1; remainingB -= 1
                case "\\": break // Git's “No newline at end of file” marker.
                default: throw DeskError("Formato de diff no compatible; se conserva el resumen de Git.")
                }
                guard remainingA >= 0, remainingB >= 0 else { throw DeskError("Diff incompleto.") }
            }
        }
        try flush()
        guard remainingA == 0, remainingB == 0 else { throw DeskError("Diff incompleto.") }
        while a < left.count || b < right.count { try append(a < left.count, b < right.count) }
        rows = try DiffLineAlignment.make(left, right)
        if (before.utf8.last == 10) != (after.utf8.last == 10), !rows.isEmpty {
            rows[rows.count - 1].differentEnding = true
        }
        return rows
    }
    private static func lines(_ text: String) -> [String] {
        guard !text.isEmpty else { return [] }
        var result = text.components(separatedBy: "\n")
        if text.utf8.last == 10 { result.removeLast() }
        return result
    }
}
