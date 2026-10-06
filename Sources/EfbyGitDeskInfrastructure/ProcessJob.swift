import Foundation
import Darwin
import EfbyGitDeskDomain

// All shared mutable state, including Process launch/termination, is protected by
// lock. Pipe readers have independent buffers and are joined before the result.
// Tested with concurrent stdout/stderr, timeout and cancellation.
final class ProcessJob: @unchecked Sendable {
    private let lock = NSLock()
    private let process = Process()
    private var cancelled = false
    private var timedOut = false
    private var finished = false
    private var drainDeadline: Date?
    private var out = Data()
    private var err = Data()
    private var truncated = false
    private let input: Data?
    private let limit: Int
    private let timeout: TimeInterval
    private let stdout = Pipe()
    private let stderr = Pipe()
    private let stdin = Pipe()

    init(executable: String, arguments: [String], directory: String, input: Data?,
         environment: [String: String], limit: Int, timeout: TimeInterval) {
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: directory)
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = env["PATH"] ?? "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        environment.forEach { env[$0] = $1 }
        process.environment = env
        process.standardOutput = stdout; process.standardError = stderr; process.standardInput = stdin
        self.input = input; self.limit = limit; self.timeout = timeout
    }
    func run() throws -> ProcessResult {
        lock.lock()
        if cancelled { lock.unlock(); throw CancellationError() }
        do { try process.run() } catch { lock.unlock(); throw DeskError("No se pudo iniciar Git: \(error.localizedDescription)") }
        lock.unlock()
        let readers = DispatchGroup()
        for (handle, isError) in [(stdout.fileHandleForReading, false), (stderr.fileHandleForReading, true)] {
            readers.enter()
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                defer { try? handle.close(); readers.leave() }
                let fd = handle.fileDescriptor
                _ = fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK)
                var bytes = [UInt8](repeating: 0, count: 32_768)
                while true {
                    lock.lock(); let deadline = drainDeadline; lock.unlock()
                    if let deadline, Date.now >= deadline { lock.lock(); truncated = true; lock.unlock(); break }
                    var descriptor = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
                    let ready = poll(&descriptor, 1, 100)
                    if ready < 0 && errno != EINTR { break }
                    guard ready > 0 else { continue }
                    let count = Darwin.read(fd, &bytes, bytes.count)
                    if count == 0 { break }
                    if count < 0 { if errno == EAGAIN || errno == EINTR { continue }; break }
                    let data = Data(bytes.prefix(count))
                    lock.lock()
                    let current = isError ? err.count : out.count
                    let remaining = max(0, limit - current)
                    if isError { err.append(data.prefix(remaining)) } else { out.append(data.prefix(remaining)) }
                    if data.count > remaining { truncated = true }
                    lock.unlock()
                }
            }
        }
        readers.enter()
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            defer { try? stdin.fileHandleForWriting.close(); readers.leave() }
            guard let input else { return }
            let fd = stdin.fileHandleForWriting.fileDescriptor
            _ = fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK)
            _ = fcntl(fd, F_SETNOSIGPIPE, 1)
            var offset = 0
            while offset < input.count {
                lock.lock(); let stop = cancelled || timedOut || drainDeadline != nil; lock.unlock()
                if stop { break }
                var descriptor = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
                guard poll(&descriptor, 1, 100) > 0 else { continue }
                let count = input.withUnsafeBytes { Darwin.write(fd, $0.baseAddress!.advanced(by: offset), min(32_768, input.count - offset)) }
                if count > 0 { offset += count }
                else if errno != EAGAIN && errno != EINTR { break }
            }
        }
        let expiry = DispatchWorkItem { [self] in
            lock.lock()
            if !finished {
                timedOut = true
                if process.isRunning { process.terminate(); forceExitAfterGrace() }
            }
            lock.unlock()
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: expiry)
        process.waitUntilExit()
        lock.lock(); drainDeadline = Date.now.addingTimeInterval(1); lock.unlock()
        readers.wait()
        lock.lock()
        finished = true
        let wasCancelled = cancelled
        let wasTimedOut = timedOut
        let result = ProcessResult(status: process.terminationStatus, output: out, error: err, truncated: truncated)
        lock.unlock()
        expiry.cancel()
        if wasCancelled { throw CancellationError() }
        if wasTimedOut { throw DeskError("La operación agotó el tiempo de espera. Verifica el estado antes de repetirla.") }
        return result
    }
    // Signal only the still-owned process. Descendants retaining pipe handles cannot
    // block completion: readers and writer have a bounded drain after this exit.
    private func forceExitAfterGrace() {
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) { [self] in
            lock.lock(); defer { lock.unlock() }
            if !finished && process.isRunning { _ = kill(process.processIdentifier, SIGKILL) }
        }
    }
    func cancel() {
        lock.lock()
        cancelled = true
        if process.isRunning { process.terminate(); forceExitAfterGrace() }
        lock.unlock()
    }
}
