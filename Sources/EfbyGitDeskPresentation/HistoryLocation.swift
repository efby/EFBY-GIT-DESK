import EfbyGitDeskDomain

/// Positions of the checked-out commit and its configured tracking branch.
/// These are repository facts, independent of the commits selected for comparison.
struct HistoryLocation {
    let localOID: String
    let localName: String
    let remoteOID: String?
    let remoteName: String?
    let ahead: Int?
    let behind: Int?

    init(snapshot: RepositorySnapshot, branches: [Branch]) {
        localOID = snapshot.head
        localName = snapshot.branch.isEmpty || snapshot.branch == "(detached)"
            ? "HEAD separado" : snapshot.branch
        let upstream = snapshot.upstream.isEmpty
            ? branches.first(where: { $0.current })?.upstream ?? ""
            : snapshot.upstream
        let tracking = branches.first { $0.remote && $0.name == upstream }
        remoteOID = tracking?.oid
        remoteName = tracking?.name
        ahead = tracking == nil ? nil : snapshot.ahead
        behind = tracking == nil ? nil : snapshot.behind
    }

    func accessibilitySuffix(for oid: String) -> String {
        var details: [String] = []
        if oid == localOID {
            details.append("commit de mi equipo, rama \(localName)")
            if let behind, behind > 0 { details.append("\(behind) commits detrás del remoto") }
            if let ahead, ahead > 0 { details.append("\(ahead) commits delante del remoto") }
        }
        if oid == remoteOID, let remoteName { details.append("commit remoto, rama \(remoteName)") }
        return details.isEmpty ? "" : ", " + details.joined(separator: ", ")
    }
}
