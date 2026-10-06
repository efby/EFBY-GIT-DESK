import Foundation
import EfbyGitDeskApplication
import EfbyGitDeskDomain

public actor BitbucketClient: HostingProviderPort {
    private let vault: KeychainVault
    private let session: URLSession
    private let retryWait: @Sendable (Double) async throws -> Void
    private let tokenLoader: @Sendable (String) async throws -> Data
    public init(vault: KeychainVault, configuration: URLSessionConfiguration = .ephemeral,
                tokenLoader: (@Sendable (String) async throws -> Data)? = nil,
                retryWait: @escaping @Sendable (Double) async throws -> Void = { try await Task.sleep(for: .seconds($0)) }) {
        self.vault = vault; self.retryWait = retryWait
        self.tokenLoader = tokenLoader ?? { id in try await vault.load(id: id) }
        let config = configuration
        config.timeoutIntervalForRequest = 25
        config.urlCredentialStorage = nil
        self.session = URLSession(configuration: config, delegate: NoRedirectDelegate(), delegateQueue: nil)
    }
    public func saveToken(email: String, token: String) async throws -> ConnectionProfile {
        guard email.contains("@"), !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DeskError("Ingresa correo Atlassian y un API token.")
        }
        let profile = ConnectionProfile(id: UUID().uuidString, email: email)
        try await vault.save(id: profile.id, value: Data(token.utf8))
        return profile
    }
    public func removeToken(profile: ConnectionProfile) async throws { try await vault.delete(id: profile.id) }
    public func repositories(profile: ConnectionProfile) async throws -> [CloudRepository] {
        let workspaces = try await pages(URL(string: "https://api.bitbucket.org/2.0/user/workspaces?pagelen=100")!, profile: profile)
        var repositories: [CloudRepository] = []
        for entry in workspaces {
            guard let workspace = entry["workspace"] as? [String: Any], let slug = workspace["slug"] as? String,
                  let safe = slug.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else { continue }
            let values = try await pages(URL(string: "https://api.bitbucket.org/2.0/repositories/\(safe)?pagelen=100")!, profile: profile)
            for value in values {
                let repository = value
                guard let uuid = repository["uuid"] as? String, let name = repository["name"] as? String else { continue }
                let fullName = repository["full_name"] as? String ?? name
                let links = repository["links"] as? [String: Any]
                let clones = links?["clone"] as? [[String: Any]] ?? []
                let ssh = clones.first { $0["name"] as? String == "ssh" }?["href"] as? String ?? "git@bitbucket.org:\(fullName).git"
                let https = "https://bitbucket.org/\(fullName).git"
                repositories.append(CloudRepository(id: uuid, name: name, fullName: fullName, sshURL: ssh, httpsURL: https))
            }
        }
        return repositories.sorted { $0.fullName.localizedStandardCompare($1.fullName) == .orderedAscending }
    }
    private func pages(_ initial: URL, profile: ConnectionProfile) async throws -> [[String: Any]] {
        let token = try await tokenLoader(profile.id)
        let authorization = (Data((profile.email + ":").utf8) + token).base64EncodedString()
        var next: URL? = initial
        var seen: Set<URL> = []
        var values: [[String: Any]] = []
        while let url = next {
            try Task.checkCancellation()
            guard Self.validAPIURL(url), seen.count < 1_000, seen.insert(url).inserted else { throw DeskError("Bitbucket devolvió una paginación no válida.") }
            var request = URLRequest(url: url)
            request.setValue("Basic " + authorization, forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let (data, response) = try await read(request)
            guard data.count <= 8 * 1024 * 1024 else { throw DeskError("La respuesta de Bitbucket supera 8 MB; el catálogo no se presenta como completo.") }
            guard let response = response as? HTTPURLResponse else { throw DeskError("Respuesta de Bitbucket no válida.") }
            guard response.statusCode == 200 else {
                switch response.statusCode {
                case 401: throw DeskError("Bitbucket rechazó el token o está expirado.")
                case 403: throw DeskError("El token no tiene los scopes de lectura requeridos.")
                case 429: throw DeskError("Bitbucket limitó las solicitudes. Espera antes de reintentar.")
                default: throw DeskError("Bitbucket no pudo responder (HTTP \(response.statusCode)).")
                }
            }
            guard let page = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = page["values"] as? [[String: Any]] else { throw DeskError("El catálogo de Bitbucket cambió su formato.") }
            guard values.count + items.count <= 100_000 else { throw DeskError("El catálogo supera el límite de 100.000 entradas.") }
            values.append(contentsOf: items)
            if let link = page["next"] as? String {
                guard let candidate = URL(string: link), Self.validAPIURL(candidate) else { throw DeskError("Se rechazó un enlace de paginación externo.") }
                next = candidate
            } else { next = nil }
        }
        return values
    }
    private func read(_ request: URLRequest) async throws -> (Data, URLResponse) {
        for attempt in 0...3 {
            let (bytes, rawResponse) = try await session.bytes(for: request)
            var data = Data()
            for try await byte in bytes {
                guard data.count < 8 * 1024 * 1024 else { throw DeskError("La respuesta de Bitbucket supera 8 MB; no se muestra un catálogo parcial.") }
                data.append(byte)
            }
            let result = (data, rawResponse)
            guard let response = rawResponse as? HTTPURLResponse, response.statusCode == 429 else { return result }
            let delay = Double(response.value(forHTTPHeaderField: "Retry-After") ?? "") ?? pow(2, Double(attempt))
            guard attempt < 3, delay >= 0, delay <= 30 else {
                throw DeskError("Bitbucket limitó las solicitudes. Respeta Retry-After antes de volver a cargar el catálogo.")
            }
            try await retryWait(delay)
        }
        throw DeskError("Bitbucket limitó las solicitudes.")
    }
    public static func validAPIURL(_ url: URL) -> Bool {
        url.scheme == "https" && url.host == "api.bitbucket.org" && url.port == nil &&
        url.user == nil && url.password == nil && url.path.hasPrefix("/2.0/")
    }
}
