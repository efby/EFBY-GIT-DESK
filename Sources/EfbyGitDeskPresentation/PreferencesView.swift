import SwiftUI

public struct PreferencesView: View {
    @Bindable private var model: DeskModel
    public init(model: DeskModel) { self.model = model }
    public var body: some View {
        Form {
            Section("Espacio de trabajo") {
                Toggle("Mostrar terminal inferior", isOn: $model.terminalVisible)
                Slider(value: $model.terminalHeight, in: 140...500) { Text("Altura del terminal") }
                Button("Restablecer distribución") {
                    model.branchWidth = 180; model.detailWidth = 340; model.sidebarWidth = 340; model.terminalHeight = 230
                    model.persistLayout()
                }
                Text("Las pestañas, el repositorio seleccionado y los anchos de paneles se guardan localmente. Las shells se inician por una acción tuya.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("EFBY Git Desk 0.1.0") {
                Text("Español · Apariencia oscura · Bitbucket Cloud")
                Text(model.gitVersion).font(.caption.monospaced())
                Text("Versión de desarrollo para pruebas locales.").foregroundStyle(.secondary)
            }
        }.formStyle(.grouped).frame(width: 490, height: 350)
            .onChange(of: model.terminalVisible) { _, _ in model.persistLayout() }
            .onChange(of: model.terminalHeight) { _, _ in model.persistLayout() }
    }
}
