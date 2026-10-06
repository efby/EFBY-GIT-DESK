import SwiftUI

struct TerminalPane: View {
    @Bindable var model: DeskModel
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Label("Terminal", systemImage: "terminal").font(.caption.weight(.semibold))
                ForEach(model.currentTerminals) { tab in
                    Button(tab.title) { model.selectedTerminal = tab.id }
                        .buttonStyle(.bordered).tint(tab.id == model.activeTerminal?.id ? .teal : .gray)
                }
                Button("Nueva sesión", systemImage: "plus") { model.startTerminal() }.labelStyle(.iconOnly).disabled(!model.mutable)
                if let tab = model.activeTerminal {
                    Button("Cerrar sesión", systemImage: "xmark") { model.closeTerminal(tab) }.labelStyle(.iconOnly)
                    if tab.driver.inputPaused { Text("Entrada pausada durante la edición de HEAD").font(.caption).foregroundStyle(.orange) }
                }
                Spacer()
                Slider(value: $model.terminalHeight, in: 140...500).frame(width: 100).accessibilityLabel("Altura del terminal")
                    .onChange(of: model.terminalHeight) { _, _ in model.persistLayout() }
                Button("Ocultar terminal", systemImage: "chevron.down") { model.terminalVisible = false; model.persistLayout() }.labelStyle(.iconOnly)
            }.controlSize(.small).padding(.horizontal, 12).padding(.vertical, 7)
            Divider()
            if let tab = model.activeTerminal {
                NativeTerminal(tab: tab, output: tab.driver.output).id(tab.id)
            } else {
                VStack(spacing: 8) {
                    Text("El terminal se abre por una acción tuya.").font(.caption).foregroundStyle(.secondary)
                    Button("Iniciar shell en este repositorio") { model.startTerminal() }.disabled(!model.mutable)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }.background(.black.opacity(0.25))
    }
}
