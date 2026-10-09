import SwiftUI

struct GitBranchMark: Shape {
    func path(in rect: CGRect) -> Path {
        let unit = min(rect.width, rect.height) / 22
        let origin = CGPoint(x: rect.midX - 11 * unit, y: rect.midY - 11 * unit)
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: origin.x + x * unit, y: origin.y + y * unit)
        }
        var path = Path()
        path.move(to: point(5, 2))
        path.addLine(to: point(5, 14.5))
        path.move(to: point(7.5, 17))
        path.addCurve(to: point(17, 7.5), control1: point(13, 17), control2: point(17, 13))
        path.addEllipse(in: CGRect(x: origin.x + 2.5 * unit, y: origin.y + 14.5 * unit,
                                width: 5 * unit, height: 5 * unit))
        path.addEllipse(in: CGRect(x: origin.x + 14.5 * unit, y: origin.y + 2.5 * unit,
                                width: 5 * unit, height: 5 * unit))
        return path
    }
}
