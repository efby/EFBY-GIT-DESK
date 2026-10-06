import SwiftUI
import EfbyGitDeskDomain

struct ConnectionsSheet: View {
    @Bindable var model: DeskModel
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var token = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Conexiones Bitbucket Cloud").font(.title2.bold())
            Text("SSH y las credenciales heredadas sirven para Git. Un API token habilita el catálogo REST.")
                .foregroundStyle(.secondary)
            Picker("Transporte Git", selection: $model.profileID) {
                Text("Heredado / SSH").tag("")
                ForEach(model.profiles) { Text($0.email).tag($0.id) }
            }
            Divider()
            Text("Agregar API token").font(.headline)
            TextField("Correo de la cuenta Atlassian", text: $email).textFieldStyle(.roundedBorder)
            SecureField("API token", text: $token).textFieldStyle(.roundedBorder)
            Text("Scopes: read:workspace:bitbucket y read:repository:bitbucket. Para push, además write:repository:bitbucket.")
                .font(.caption).foregroundStyle(.secondary)
            Button("Guardar en Keychain") {
                let submitted = token; token = ""
                model.saveConnection(email: email, token: submitted)
            }.disabled(model.busy || token.isEmpty || email.isEmpty)
            ForEach(model.profiles) { profile in
                HStack {
                    Label(profile.email, systemImage: "lock.shield")
                    Spacer()
                    Button("Retirar conexión", role: .destructive) { model.disconnect(profile) }.disabled(model.busy)
                }
            }
            Text("Retirar una conexión local no revoca el token en Atlassian.").font(.caption).foregroundStyle(.secondary)
            HStack { Spacer(); Button("Listo") { token = ""; dismiss() }.keyboardShortcut(.defaultAction) }
        }.padding(26).frame(width: 580)
    }
}
