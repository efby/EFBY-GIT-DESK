import Foundation

public struct Repository: Identifiable, Codable, Hashable, Sendable {
    public var id: String { path }
    public let path: String
    public let gitDirectory: String
    public let commonDirectory: String
    public var name: String
    public var trusted: Bool
    public var favorite: Bool
    public var group: String
    public var lastOpened: Date
    public var pendingCheckout: Bool
    public let identity: String?
    public var inspectionReason: String?
    public var linkedWorktree: Bool { gitDirectory != commonDirectory }

    public init(path: String, gitDirectory: String, commonDirectory: String,
                name: String, trusted: Bool = false, favorite: Bool = false,
                group: String = "", lastOpened: Date = .now, pendingCheckout: Bool = false, inspectionReason: String? = nil, identity: String? = nil) {
        self.path = path; self.gitDirectory = gitDirectory
        self.commonDirectory = commonDirectory; self.name = name
        self.trusted = trusted; self.favorite = favorite
        self.group = group; self.lastOpened = lastOpened
        self.pendingCheckout = pendingCheckout; self.inspectionReason = inspectionReason; self.identity = identity
    }
}
