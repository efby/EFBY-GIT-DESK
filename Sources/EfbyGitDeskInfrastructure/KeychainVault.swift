import Foundation
import Security
import EfbyGitDeskDomain

public actor KeychainVault {
    public static let service = "com.efby.EfbyGitDesk.credentials"
    public init() {}
    public func save(id: String, value: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service, kSecAttrAccount as String: id
        ]
        let result = SecItemUpdate(query as CFDictionary, [kSecValueData as String: value] as CFDictionary)
        if result == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = value
            guard SecItemAdd(insert as CFDictionary, nil) == errSecSuccess else { throw DeskError("Keychain no pudo guardar la credencial.") }
        } else if result != errSecSuccess { throw DeskError("Keychain está bloqueado o denegó el acceso.") }
    }
    func load(id: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service, kSecAttrAccount as String: id,
            kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var value: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &value) == errSecSuccess, let data = value as? Data else {
            throw DeskError("Credencial ausente o Keychain bloqueado. Vuelve a conectar tu cuenta.")
        }
        return data
    }
    public func delete(id: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service, kSecAttrAccount as String: id
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard [errSecSuccess, errSecItemNotFound].contains(status) else { throw DeskError("No se pudo eliminar la credencial de Keychain.") }
    }
    func operation(profile: ConnectionProfile) throws -> String {
        let token = try load(id: profile.id)
        let reference = "operation." + UUID().uuidString
        var value = Data(String(Date.now.timeIntervalSince1970).utf8)
        value.append(0); value.append(token)
        try save(id: reference, value: value)
        return reference
    }
    public static func askpass(reference: String, prompt: String) throws -> String {
        guard reference.hasPrefix("operation."),
              let start = prompt.range(of: "https://"),
              let end = prompt[start.lowerBound...].firstIndex(of: "'"),
              let url = URL(string: String(prompt[start.lowerBound..<end])),
              url.scheme == "https", url.host == "bitbucket.org", url.port == nil,
              url.password == nil, url.user == nil || url.user == "x-bitbucket-api-token-auth" else { throw DeskError("Solicitud de credencial no autorizada.") }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecAttrAccount as String: reference,
            kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var value: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &value) == errSecSuccess,
              let data = value as? Data, let zero = data.firstIndex(of: 0),
              let created = TimeInterval(String(decoding: data[..<zero], as: UTF8.self)),
              Date.now.timeIntervalSince1970 - created < 60 else { throw DeskError("La solicitud de credencial expiró.") }
        if prompt.lowercased().contains("username") { return "x-bitbucket-api-token-auth" }
        guard prompt.lowercased().contains("password") else { throw DeskError("Solicitud no autorizada.") }
        return String(decoding: data[data.index(after: zero)...], as: UTF8.self)
    }
}
