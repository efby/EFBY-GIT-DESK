import Foundation
import Testing
import EfbyGitDeskDomain
import EfbyGitDeskInfrastructure

@Suite(.serialized) @MainActor struct TerminalTests {
    @Test func realPTYSupportsDirectoryUnicodeResizeInterruptionAndExit() async throws {
        let f = try await GitFixture.make(); defer { f.cleanup() }
        let terminal = PTYTerminal(shell: "/bin/sh", login: false)
        try terminal.start(directory: f.folder.path, columns: 80, rows: 24)
        defer { terminal.close() }
        try await waitFor("shell", terminal: terminal, seconds: 12) {
            terminal.output.contains("$") || terminal.output.contains("%")
        }
        terminal.write("pwd; printf 'Unicode: café ✓\\n'\r")
        try await waitFor("pwd/unicode", terminal: terminal, seconds: 12) {
            terminal.output.contains("Unicode: café ✓")
                && terminal.output.replacingOccurrences(of: "\n", with: "").contains(f.folder.path)
        }
        terminal.resize(columns: 93, rows: 31)
        terminal.write("stty size\r")
        try await waitFor("resize", terminal: terminal) { terminal.output.contains("31 93") }
        terminal.write("cat\r")
        terminal.write("CAT_READY\r")
        try await waitFor("foreground command", terminal: terminal, seconds: 12) {
            terminal.output.components(separatedBy: "CAT_READY").count >= 3
        }
        terminal.inputPaused = true
        terminal.write("\u{3}")
        terminal.write("echo SHOULD_NOT_RUN\r")
        terminal.inputPaused = false
        terminal.write("printf 'AFTER_INTERRUPT\\n'\r")
        try await waitFor("interrupt", terminal: terminal) {
            terminal.output.components(separatedBy: "AFTER_INTERRUPT").count >= 3
        }
        #expect(!terminal.output.contains("SHOULD_NOT_RUN"))
        terminal.write("exit\r")
        try await waitFor("exit", terminal: terminal) { !terminal.running }
    }
    private func waitFor(_ label: String, terminal: PTYTerminal, seconds: TimeInterval = 5,
                         _ condition: @MainActor () -> Bool) async throws {
        let deadline = Date.now.addingTimeInterval(seconds)
        while !condition() && Date.now < deadline { try await Task.sleep(for: .milliseconds(30)) }
        guard condition() else { throw DeskError("PTY \(label): \(terminal.output)") }
    }
}
