import SwiftUI
import AppKit
import EfbyGitDeskPresentation

@main struct EfbyGitDeskApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model: DeskModel?
    @State private var startupError: String?
    init() {
        do {
            _model = State(initialValue: try MacComposition.makeModel())
            _startupError = State(initialValue: nil)
        }
        catch {
            _model = State(initialValue: nil)
            _startupError = State(initialValue: error.localizedDescription)
        }
    }
    var body: some Scene {
        WindowGroup("EFBY Git Desk") {
            if let model {
                WorkspaceView(model: model)
                    .onAppear { delegate.model = model }
                    .onOpenURL { url in if url.isFileURL { model.open(path: url.path) } }
            } else {
                StartupFailureView(message: startupError ?? "No se pudo abrir el catálogo local.", retry: retryStartup)
            }
        }
        .defaultSize(width: 1480, height: 880)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Abrir carpeta…") { model?.chooseRepository() }
                    .keyboardShortcut("o")
                    .disabled(model == nil)
            }
            CommandMenu("Repositorio") {
                Button("Actualizar") { model?.refresh(forceHistory: true) }
                    .keyboardShortcut("r")
                    .disabled(model == nil)
                Button("Mostrar terminal") {
                    model?.terminalVisible.toggle()
                    model?.persistLayout()
                }
                .keyboardShortcut("j")
                .disabled(model == nil)
            }
        }
        Settings {
            if let model { PreferencesView(model: model) }
            else { Text("El catálogo local debe estar disponible para abrir Preferencias.").padding() }
        }
    }

    private func retryStartup() {
        do {
            model = try MacComposition.makeModel()
            startupError = nil
        } catch {
            startupError = error.localizedDescription
        }
    }
}
