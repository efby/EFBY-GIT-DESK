import Foundation

struct DiffViewportStatus: Equatable, Sendable {
    var firstRow = 0
    var lastRow = 0
    var visibleChange = false
    var linesToNext: Int?
    var message: String {
        if let linesToNext {
            return (visibleChange ? "Cambio visible · " : "") + (linesToNext == 1 ? "Falta 1 línea para el próximo cambio" : "Faltan \(linesToNext) líneas para el próximo cambio")
        }
        return visibleChange ? "Cambio visible · Sin más cambios hacia abajo" : "Sin más cambios hacia abajo"
    }
    static func make(firstRow: Int, lastRow: Int, blocks: [DiffChangeBlock]) -> Self {
        let visible = blocks.contains { $0.lastRow >= firstRow && $0.firstRow <= lastRow }
        let next = blocks.first { $0.firstRow > lastRow }
        return Self(firstRow: firstRow, lastRow: lastRow, visibleChange: visible,
                    linesToNext: next.map { $0.firstRow - lastRow })
    }
}
