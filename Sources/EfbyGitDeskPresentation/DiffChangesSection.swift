import SwiftUI

struct DiffChangesSection: View {
    let blocks: [DiffChangeBlock]
    let map: [Bool]
    let rowCount: Int
    @Binding var jump: DiffJumpTarget?
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label("Modificaciones", systemImage: "map").font(.caption.bold())
                Text("\(blocks.count) \(blocks.count == 1 ? "bloque" : "bloques")").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Cambio anterior", systemImage: "chevron.up", action: previous).labelStyle(.iconOnly)
                    .disabled(blocks.isEmpty || selectedIndex == 0)
                Button("Cambio siguiente", systemImage: "chevron.down", action: next).labelStyle(.iconOnly)
                    .disabled(blocks.isEmpty || selectedIndex == blocks.count - 1)
            }
            if blocks.isEmpty {
                Text("No hay cambios de líneas.").font(.caption).foregroundStyle(.secondary)
            } else {
                GeometryReader { geometry in
                    Canvas { context, size in
                        for index in map.indices where map[index] {
                            let rect = CGRect(x: CGFloat(index) * size.width / CGFloat(map.count), y: 3,
                                              width: max(2, size.width / CGFloat(map.count)), height: size.height - 6)
                            context.fill(Path(rect), with: .color(.orange))
                        }
                        if let jump, rowCount > 0 {
                            let x = CGFloat(jump.row) * size.width / CGFloat(rowCount)
                            context.fill(Path(CGRect(x: x, y: 0, width: 3, height: size.height)), with: .color(.teal))
                        }
                    }.background(.primary.opacity(0.06))
                        .onTapGesture { location in selectNearest(location.x / max(1, geometry.size.width)) }
                }.frame(height: 18).accessibilityHidden(true)
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 8) {
                        ForEach(Array(blocks.enumerated()), id: \.element.id) { index, block in
                            Button { jump = DiffJumpTarget(row: block.firstRow) } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Cambio \(index + 1) · Base \(range(block.beforeLines)) → Destino \(range(block.afterLines))")
                                    Text(index == 0 ? "A \(block.gapLines) líneas del inicio" : "\(block.gapLines) líneas sin cambios desde el anterior")
                                        .foregroundStyle(.secondary)
                                }.font(.caption).padding(6)
                            }.buttonStyle(.plain)
                                .background(jump?.row == block.firstRow ? Color.teal.opacity(0.2) : Color.primary.opacity(0.05))
                                .clipShape(.rect(cornerRadius: 5))
                                .help("Ir al cambio \(index + 1)")
                        }
                    }
                }.fixedSize(horizontal: false, vertical: true)
            }
        }.padding(.horizontal, 12).padding(.vertical, 8)
    }
    private var selectedIndex: Int? { blocks.firstIndex { $0.firstRow == jump?.row } }
    private func previous() { if !blocks.isEmpty { jump = DiffJumpTarget(row: blocks[max(0, (selectedIndex ?? 1) - 1)].firstRow) } }
    private func next() { if !blocks.isEmpty { jump = DiffJumpTarget(row: blocks[min(blocks.count - 1, (selectedIndex ?? -1) + 1)].firstRow) } }
    private func selectNearest(_ fraction: CGFloat) {
        let row = Int(max(0, min(1, fraction)) * CGFloat(rowCount))
        if let block = blocks.min(by: { abs($0.firstRow - row) < abs($1.firstRow - row) }) { jump = DiffJumpTarget(row: block.firstRow) }
    }
    private func range(_ value: ClosedRange<Int>?) -> String {
        guard let value else { return "—" }
        return value.lowerBound == value.upperBound ? "\(value.lowerBound)" : "\(value.lowerBound)–\(value.upperBound)"
    }
}
