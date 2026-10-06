import Foundation
import Observation
import Darwin
import CPTY
import EfbyGitDeskApplication
import EfbyGitDeskDomain

@MainActor @Observable public final class PTYTerminal: TerminalPort {
    public private(set) var output = ""
    public private(set) var running = false
    public var inputPaused = false
    private var master: Int32 = -1
    private var child: pid_t = 0
    @ObservationIgnored private var source: DispatchSourceRead?
    private var screen = TerminalScreen()
    @ObservationIgnored private let shellOverride: String?
    @ObservationIgnored private let login: Bool
    @ObservationIgnored private var pendingInput = Data()
    @ObservationIgnored private var writer: Task<Void, Never>?
    public init(shell: String? = nil, login: Bool = true) { shellOverride = shell; self.login = login }
    public func start(directory: String, columns: Int, rows: Int) throws {
        guard !running else { return }
        let shell = shellOverride ?? ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        guard ["/bin/zsh", "/bin/bash", "/bin/sh"].contains(shell) else { throw DeskError("Selecciona una shell del sistema compatible.") }
        let result = efby_pty_start(directory, shell, Int32(columns), Int32(rows), login ? 1 : 0, &master, &child)
        guard result == 0 else { throw DeskError("No se pudo crear el terminal PTY.") }
        screen.columns = columns
        running = true
        let fd = master
        let pid = child
        let reader = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .global(qos: .userInitiated))
        reader.setEventHandler { @Sendable [weak self] in
            var bytes = [UInt8](repeating: 0, count: 16_384)
            let count = Darwin.read(fd, &bytes, bytes.count)
            if count > 0 {
                let data = Data(bytes.prefix(count))
                Task { @MainActor [weak self] in
                    guard let self, self.child == pid, self.running else { return }
                    self.screen.consume(data); self.output = self.screen.output
                }
            }
        }
        reader.setCancelHandler { @Sendable in Darwin.close(fd) }
        source = reader; reader.resume()
        DispatchQueue.global().async { [weak self] in
            var status: Int32 = 0
            _ = waitpid(pid, &status, 0)
            Task { @MainActor [weak self] in
                guard let self, self.child == pid else { return }
                self.running = false; self.source?.cancel(); self.source = nil; self.master = -1
                self.output += "\n[Sesión terminada]\n"
            }
        }
    }
    public func write(_ text: String) {
        guard running, master >= 0, !inputPaused || text == "\u{3}" else { return }
        let data = Data(text.utf8)
        if inputPaused && text == "\u{3}" {
            data.withUnsafeBytes { _ = Darwin.write(master, $0.baseAddress, data.count) }; return
        }
        guard pendingInput.count + data.count <= 512 * 1024 else {
            output += "\n[Entrada demasiado grande; divide el pegado en bloques menores de 512 KB.]\n"; return
        }
        pendingInput.append(data)
        guard writer == nil else { return }
        writer = Task { [weak self] in
            guard let self else { return }
            defer { self.writer = nil }
            while !Task.isCancelled && self.running && !self.pendingInput.isEmpty {
                if !self.inputPaused {
                    let count = self.pendingInput.withUnsafeBytes { Darwin.write(self.master, $0.baseAddress, min(16_384, self.pendingInput.count)) }
                    if count > 0 { self.pendingInput.removeFirst(count) }
                    else if errno != EAGAIN && errno != EINTR { break }
                }
                try? await Task.sleep(for: .milliseconds(10))
            }
        }
    }
    public func resize(columns: Int, rows: Int) {
        screen.columns = max(20, columns)
        if master >= 0 { _ = efby_pty_resize(master, Int32(max(20, columns)), Int32(max(5, rows))) }
    }
    public func close() {
        if child > 0 && running { kill(-child, SIGHUP) }
        writer?.cancel(); writer = nil; pendingInput.removeAll()
        source?.cancel(); source = nil; master = -1; running = false; child = 0
    }
}
