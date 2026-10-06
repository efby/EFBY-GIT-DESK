import SwiftUI
import AppKit
import EfbyGitDeskDomain

struct CloneSheet: View {
    @Bindable var model: DeskModel
    @Environment(\.dismiss) private var dismiss
    @State private var source = ""
    @State private var parent = ""
    @State private var folder = ""
    @State private var catalog: [CloudRepository] = []
    @State private var catalogSearch = ""
    @State private var loading = false
    @State private var failure: String?
    @State private var preferSSH = true
    @State private var request: Task<Void, Never>?
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Clonar desde Bitbucket").font(.title2.bold())
            Picker("Conexión", selection: $model.profileID) {
                Text("Heredada / SSH").tag("")
                ForEach(model.profiles) { Text($0.email).tag($0.id) }
            }
            HStack {
                Button("Cargar catálogo") { loadCatalog() }.disabled(model.profile == nil || loading)
                if loading { ProgressView().controlSize(.small) }
                Toggle("Usar SSH", isOn: $preferSSH)
            }
            if !catalog.isEmpty {
                TextField("Buscar repositorios en el catálogo", text: $catalogSearch).textFieldStyle(.roundedBorder)
                List(catalog.filter { catalogSearch.isEmpty || $0.fullName.localizedCaseInsensitiveContains(catalogSearch) }) { repository in
                    Button(repository.fullName) {
                        source = preferSSH ? repository.sshURL : repository.httpsURL
                        folder = repository.name
                    }.buttonStyle(.plain)
                }.frame(height: 140)
            }
            if let failure { Text(failure).font(.caption).foregroundStyle(.orange) }
            TextField("URL SSH o HTTPS de Bitbucket", text: $source).textFieldStyle(.roundedBorder)
            HStack {
                Text(parent.isEmpty ? "Elige la carpeta contenedora" : parent).lineLimit(1).truncationMode(.middle)
                Spacer()
                Button("Elegir carpeta") {
                    let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false
                    if panel.runModal() == .OK { parent = panel.url?.path ?? "" }
                }
            }
            TextField("Nombre de la nueva carpeta", text: $folder).textFieldStyle(.roundedBorder)
            Label("El clon se crea sin checkout. Debes confiar en él para materializar archivos.", systemImage: "lock.shield")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Cancelar") { dismiss() }
                Spacer()
                Button("Clonar") {
                    model.clone(source: source, destination: URL(fileURLWithPath: parent).appendingPathComponent(folder).path)
                    dismiss()
                }.buttonStyle(.borderedProminent)
                    .disabled(model.busy || source.isEmpty || parent.isEmpty || folder.isEmpty || folder.contains("/") || folder == "." || folder == "..")
            }
        }.padding(26).frame(width: 600).onDisappear { request?.cancel() }
    }
    private func loadCatalog() {
        guard let profile = model.profile else { return }
        loading = true; failure = nil
        request?.cancel()
        request = Task {
            defer { loading = false }
            do { catalog = try await model.service.cloud.repositories(profile: profile) }
            catch is CancellationError {}
            catch { failure = error.localizedDescription }
        }
    }
}
