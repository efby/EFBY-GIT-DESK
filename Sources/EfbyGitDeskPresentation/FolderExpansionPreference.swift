import Foundation

enum FolderExpansionPreference {
    static func key(scope: String, repositoryID: String) -> String {
        "folders.\(scope)." + Data(repositoryID.utf8).base64EncodedString()
    }

    static func decode(_ value: String?) -> Set<String> {
        guard let value, let data = value.data(using: .utf8),
              let identifiers = try? JSONDecoder().decode(Set<String>.self, from: data) else { return [] }
        return identifiers
    }

    static func encode(_ identifiers: Set<String>) -> String? {
        guard let data = try? JSONEncoder().encode(identifiers) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func allExpanded(collapsed: Set<String>, visible: Set<String>) -> Bool {
        collapsed.isDisjoint(with: visible)
    }

    static func toggleAll(collapsed: Set<String>, visible: Set<String>) -> Set<String> {
        allExpanded(collapsed: collapsed, visible: visible)
            ? collapsed.union(visible) : collapsed.subtracting(visible)
    }
}
