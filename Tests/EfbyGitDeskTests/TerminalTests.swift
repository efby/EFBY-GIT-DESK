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
        terminal.write("pwd; printf 'Unicode: café ✓\\n'\r")
        try await waitFor("pwd/unicode", terminal: terminal) { terminal.output.contains("Unicode: café ✓") && terminal.output.replacingOccurrences(of: "\n", with: "").contains(f.folder.path) }
        terminal.resize(columns: 93, rows: 31)
        terminal.write("stty size\r")
        try await waitFor("resize", terminal: terminal) { terminal.output.contains("31 93") }
        terminal.write("sleep 30\r")
        try await Task.sleep(for: .milliseconds(150))
        terminal.inputPaused = true
        terminal.write("\u{3}")
        terminal.write("echo SHOULD_NOT_RUN\r")
        terminal.inputPaused = false
        terminal.write("printf 'AFTER_INTERRUPT\\n'\r")
        try await waitFor("interrupt", terminal: terminal) { terminal.output.contains("AFTER_INTERRUPT") }
        #expect(!terminal.output.contains("SHOULD_NOT_RUN"))
        terminal.write("exit\r")
        try await waitFor("exit", terminal: terminal) { !terminal.running }
    }
    private func waitFor(_ label: String, terminal: PTYTerminal, _ condition: @MainActor () -> Bool) async throws {
        let deadline = Date.now.addingTimeInterval(5)
        while !condition() && Date.now < deadline { try await Task.sleep(for: .milliseconds(30)) }
        guard condition() else { throw DeskError("PTY \(label): \(terminal.output)") }
    }
}
