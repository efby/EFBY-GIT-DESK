import Foundation

public struct RepositoryIdentityChangedError: Error, LocalizedError, Sendable {
    public init() {}
    public var errorDescription: String? {
        "El directorio Git cambió. Vuelve a abrir y revisar la confianza del repositorio."
    }
}
