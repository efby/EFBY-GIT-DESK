import SwiftUI
import AppKit

struct StartupFailureView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.largeTitle)
                .accessibilityHidden(true)
            Text("EFBY Git Desk no pudo iniciar")
                .font(.title2.bold())
            Text(message)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
            Text("Comprueba que tu cuenta tenga acceso al catálogo local y vuelve a intentarlo. Tus repositorios permanecen en sus carpetas.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack {
                Button("Salir") { NSApplication.shared.terminate(nil) }
                Button("Reintentar", action: retry)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(32)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
