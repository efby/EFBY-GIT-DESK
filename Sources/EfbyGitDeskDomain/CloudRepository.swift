import Foundation

public struct CloudRepository: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let fullName: String
    public let sshURL: String
    public let httpsURL: String
    public init(id: String, name: String, fullName: String, sshURL: String, httpsURL: String) {
        self.id = id; self.name = name; self.fullName = fullName
        self.sshURL = sshURL; self.httpsURL = httpsURL
    }
}
