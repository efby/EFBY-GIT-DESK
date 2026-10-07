import Foundation

public struct FileComparison: Sendable {
    public let before: String?
    public let after: String?
    public let beforeLabel: String
    public let afterLabel: String
    public let patch: String
    public let notice: String

    public init(before: String?, after: String?, beforeLabel: String, afterLabel: String, patch: String, notice: String = "") {
        self.before = before; self.after = after
        self.beforeLabel = beforeLabel; self.afterLabel = afterLabel
        self.patch = patch; self.notice = notice
    }
}
