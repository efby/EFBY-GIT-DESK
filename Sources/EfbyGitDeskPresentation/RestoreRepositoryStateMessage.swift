import Foundation

enum RestoreRepositoryStateMessage {
    static func compose(userInput: String, shortOID: String) -> String {
        let trimmed = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.localizedCaseInsensitiveContains("restore repository state to commit") {
            return trimmed
        }
        return "\(trimmed): Restore repository state to commit \(shortOID)"
    }
}
