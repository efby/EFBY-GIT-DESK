import AppKit

public enum SyntaxKind: Equatable, Sendable {
    case keyword, string, comment, number, function, type, decorator, tag
}

extension SyntaxKind {
    @MainActor var color: NSColor {
        switch self {
        case .keyword: NSColor(calibratedRed: 0.72, green: 0.53, blue: 1, alpha: 1)
        case .string: NSColor(calibratedRed: 0.93, green: 0.76, blue: 0.43, alpha: 1)
        case .comment: NSColor(calibratedRed: 0.52, green: 0.65, blue: 0.54, alpha: 1)
        case .number: NSColor(calibratedRed: 0.96, green: 0.62, blue: 0.45, alpha: 1)
        case .function: NSColor(calibratedRed: 0.4, green: 0.79, blue: 0.94, alpha: 1)
        case .type, .tag: NSColor(calibratedRed: 0.39, green: 0.81, blue: 0.68, alpha: 1)
        case .decorator: NSColor(calibratedRed: 0.94, green: 0.78, blue: 0.42, alpha: 1)
        }
    }
}
