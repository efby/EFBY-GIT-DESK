import SwiftUI

struct GraphCell: View {
    let row: GraphRow?
    private let colors: [Color] = [.teal, .orange, .purple, .blue, .pink, .green]
    var body: some View {
        Canvas { context, size in
            guard let row else { return }
            func x(_ lane: Int) -> Double { 10 + Double(lane) * 13 }
            for (index, oid) in row.before.enumerated() {
                var line = Path()
                line.move(to: CGPoint(x: x(index), y: 0))
                if let next = row.after.firstIndex(of: oid) {
                    line.addLine(to: CGPoint(x: x(next), y: size.height))
                } else { line.addLine(to: CGPoint(x: x(row.lane), y: size.height / 2)) }
                context.stroke(line, with: .color(colors[index % colors.count].opacity(0.65)), lineWidth: 1.5)
            }
            for parent in row.parents {
                if let next = row.after.firstIndex(of: parent) {
                    var line = Path(); line.move(to: CGPoint(x: x(row.lane), y: size.height / 2))
                    line.addLine(to: CGPoint(x: x(next), y: size.height))
                    context.stroke(line, with: .color(colors[row.lane % colors.count]), lineWidth: 1.5)
                }
            }
            let circle = CGRect(x: x(row.lane) - 4, y: size.height / 2 - 4, width: 8, height: 8)
            context.fill(Path(ellipseIn: circle), with: .color(colors[row.lane % colors.count]))
        }
        .frame(width: 82, height: 40).clipped().accessibilityHidden(true)
    }
}
