import Foundation

public struct ConnectionProfile: Identifiable, Codable, Sendable {
    public let id: String
    public let email: String
    public init(id: String, email: String) { self.id = id; self.email = email }
}
