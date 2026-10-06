import AppKit
import EfbyGitDeskPresentation

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var model: DeskModel?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if model?.busy == true {
            model?.cancelOperation()
            let alert = NSAlert(); alert.messageText = "Cancelando operación Git"
            alert.informativeText = "Espera a que se consulte el estado real antes de cerrar."
            alert.runModal()
            return .terminateCancel
        }
        if let model, model.activeTerminalCount > 0 {
            let alert = NSAlert(); alert.messageText = "Hay \(model.activeTerminalCount) sesiones de terminal activas"
            alert.informativeText = "Cerrar la aplicación termina estas sesiones y sus procesos."
            alert.addButton(withTitle: "Cerrar sesiones y salir"); alert.addButton(withTitle: "Volver")
            guard alert.runModal() == .alertFirstButtonReturn else { return .terminateCancel }
        }
        model?.closeAllTerminals()
        return .terminateNow
    }
}
