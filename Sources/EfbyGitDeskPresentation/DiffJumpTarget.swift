import Foundation

struct DiffJumpTarget: Equatable {
    let row: Int
    let id: UUID
    var restoreOffset: CGPoint?
    init(row: Int, restoreOffset: CGPoint? = nil) {
        self.row = row
        self.id = UUID()
        self.restoreOffset = restoreOffset
    }
}

struct LinkReturn: Equatable, Sendable {
    let fileID: String
    let line: Int
    let name: String
    let offsetX: CGFloat
    let offsetY: CGFloat
}
