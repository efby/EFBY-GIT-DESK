import SwiftUI

struct RepositoryTabs: View {
    @Bindable var model: DeskModel
    var body: some View {
        if !model.openIDs.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(model.openIDs, id: \.self) { id in
                        if let repository = model.repositories.first(where: { $0.id == id }) {
                            HStack(spacing: 6) {
                                Button(repository.name) { model.select(id) }.buttonStyle(.plain)
                                Button("Cerrar \(repository.name)", systemImage: "xmark") { model.closeRepository(id) }
                                    .labelStyle(.iconOnly).buttonStyle(.plain).disabled(model.busy)
                            }.font(.caption).padding(9)
                                .background(id == model.selectedID ? Color.teal.opacity(0.2) : .clear, in: RoundedRectangle(cornerRadius: 6))
                                .help(repository.path)
                        }
                    }
                }.padding(.horizontal, 12).padding(.top, 6)
            }
        }
    }
}
