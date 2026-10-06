import SwiftUI
import AppKit
import EfbyGitDeskPresentation

@main struct EfbyGitDeskApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model: DeskModel
    init() {
        do { _model = State(initialValue: try MacComposition.makeModel()) }
        catch {
            let alert = NSAlert(); alert.messageText = "EfbyGitDesk no pudo iniciar"; alert.informativeText = error.localizedDescription
            alert.runModal()
            fatalError("No se pudo preparar el catálogo de la aplicación.")
        }
    }
    var body: some Scene {
        WindowGroup("EfbyGitDesk") {
            WorkspaceView(model: model)
                .onAppear { delegate.model = model }
                .onOpenURL { url in if url.isFileURL { model.open(path: url.path) } }
        }
        .defaultSize(width: 1480, height: 880)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Abrir repositorio…") { model.chooseRepository() }.keyboardShortcut("o")
            }
            CommandMenu("Repositorio") {
                Button("Actualizar") { model.refresh(forceHistory: true) }.keyboardShortcut("r")
                Button("Mostrar terminal") { model.terminalVisible.toggle(); model.persistLayout() }.keyboardShortcut("j")
            }
        }
        Settings { PreferencesView(model: model) }
    }
}
