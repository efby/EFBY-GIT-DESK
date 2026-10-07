import SwiftUI

public struct PreferencesView: View {
    @State private var gitPath = ""
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
            Section("Git") {
                TextField("Ruta del ejecutable Git", text: $gitPath)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("Seleccionar…") { model.chooseGitExecutable() }
                    Button("Usar esta ruta") { model.configureGit(path: gitPath) }.disabled(gitPath.isEmpty)
                    Button("Detectar automáticamente") { model.configureGit(path: "") }
                }.disabled(model.busy)
                Text(model.gitVersion.isEmpty ? "Git pendiente de configurar" : model.gitVersion).font(.caption.monospaced())
                Text("Usa el Git existente en tu cuenta. No requiere Xcode ni permisos de administrador. Si no aparece, consulta command -v git en tu Terminal y selecciona esa ruta.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("EFBY Git Desk") {
                Text("Español · Apariencia oscura · Bitbucket Cloud")
                Text(model.gitVersion).font(.caption.monospaced())
                Text("Versión de desarrollo para pruebas locales.").foregroundStyle(.secondary)
            }
        }.formStyle(.grouped).frame(width: 600, height: 580)
            .onAppear { gitPath = model.gitExecutable }
            .onChange(of: model.gitExecutable) { _, path in gitPath = path }
            .onChange(of: model.terminalVisible) { _, _ in model.persistLayout() }
            .onChange(of: model.terminalHeight) { _, _ in model.persistLayout() }
    }
}
