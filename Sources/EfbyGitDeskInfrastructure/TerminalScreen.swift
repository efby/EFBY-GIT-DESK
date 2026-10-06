import Foundation

public struct TerminalScreen: Sendable {
    private var lines: [[Character]] = [[]]
    private var row = 0
    private var column = 0
    private var mode = 0
    private var control = ""
    private var pendingUTF8 = Data()
    private var utf8Count = 0
    public var columns = 100
    public var output: String { lines.map { String($0) }.joined(separator: "\n") }
    public init() {}
    public mutating func consume(_ bytes: Data) {
        for byte in bytes {
            if utf8Count > 0 {
                pendingUTF8.append(byte)
                if pendingUTF8.count == utf8Count {
                    for character in String(decoding: pendingUTF8, as: UTF8.self) { consume(character) }
                    pendingUTF8.removeAll(keepingCapacity: true); utf8Count = 0
                }
            } else if byte < 128 { consume(Character(UnicodeScalar(byte))) }
            else {
                utf8Count = byte < 224 ? 2 : (byte < 240 ? 3 : 4)
                pendingUTF8 = Data([byte])
            }
        }
    }
    private mutating func consume(_ character: Character) {
        if mode == 3 {
            if character == "\u{7}" { mode = 0 }
            else if character == "\u{1b}" { mode = 4 }
            return
        }
        if mode == 4 { mode = character == "\\" ? 0 : 3; return }
        if mode == 1 {
            if character == "[" { mode = 2; control = "" }
            else if character == "]" { mode = 3 }
            else { mode = 0 }
            return
        }
        if mode == 2 {
            if let byte = character.asciiValue, (64...126).contains(byte) { csi(character); mode = 0 }
            else if control.count < 100 { control.append(character) }
            else { mode = 0 }
            return
        }
        switch character {
        case "\u{1b}": mode = 1
        case "\r": column = 0
        case "\n": row += 1; ensureRow()
        case "\u{8}": column = max(0, column - 1)
        case "\t": column = min(columns - 1, ((column / 8) + 1) * 8)
        case "\u{7}", "\0": break
        default:
            if column >= columns { column = 0; row += 1 }
            ensureRow()
            while lines[row].count <= column { lines[row].append(" ") }
            lines[row][column] = character; column += 1
        }
        if lines.count > 5_000 { let count = lines.count - 5_000; lines.removeFirst(count); row = max(0, row - count) }
    }
    private mutating func ensureRow() {
        row = max(0, min(row, 5_000))
        while lines.count <= row { lines.append([]) }
    }
    private mutating func csi(_ final: Character) {
        let values = control.split(separator: ";", omittingEmptySubsequences: false).map { Int($0) ?? 0 }
        let amount = max(1, values.first ?? 1)
        switch final {
        case "A": row = max(0, row - amount)
        case "B": row += amount; ensureRow()
        case "C": column = min(columns - 1, column + amount)
        case "D": column = max(0, column - amount)
        case "G": column = min(columns - 1, amount - 1)
        case "H", "f":
            row = max(0, amount - 1); column = max(0, min(columns - 1, (values.count > 1 ? max(1, values[1]) : 1) - 1)); ensureRow()
        case "J":
            if [2, 3].contains(values.first ?? 0) { lines = [[]]; row = 0; column = 0 }
        case "K":
            ensureRow()
            if values.first == 2 { lines[row] = [] }
            else if lines[row].count > column { lines[row].removeSubrange(column...) }
        default: break // SGR and unsupported native-action sequences never execute code.
        }
    }
}
