import Foundation
import Observation
import EfbyGitDeskApplication

@MainActor @Observable public final class TerminalTab: Identifiable {
    public let id = UUID()
    public let title: String
    public let driver: any TerminalPort
    public init(title: String, driver: any TerminalPort) { self.title = title; self.driver = driver }
}
