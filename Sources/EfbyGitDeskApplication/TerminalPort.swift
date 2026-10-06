import Foundation
import EfbyGitDeskDomain

@MainActor public protocol TerminalPort: AnyObject {
    var output: String { get }
    var running: Bool { get }
    var inputPaused: Bool { get set }
    func start(directory: String, columns: Int, rows: Int) throws
    func write(_ text: String)
    func resize(columns: Int, rows: Int)
    func close()
}
