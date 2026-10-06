import SwiftUI

struct BranchSheet: View {
    @Bindable var model: DeskModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Crear rama desde HEAD").font(.title2.bold())
            TextField("Nombre de la rama", text: $name).textFieldStyle(.roundedBorder)
            Text("Se crea la referencia sin cambiar de rama ni mover tus archivos.").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Cancelar") { dismiss() }
                Spacer()
                Button("Crear rama") { model.mutate(.createBranch(name)); dismiss() }
                    .buttonStyle(.borderedProminent).disabled(name.isEmpty || !model.mutable)
            }
        }.padding(26).frame(width: 430)
    }
}
