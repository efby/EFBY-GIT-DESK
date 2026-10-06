import Foundation
import Testing
import EfbyGitDeskDomain
import EfbyGitDeskInfrastructure

struct DomainTests {
    @Test func comparisonIsExactlyTwoDifferentFullIdentifiers() throws {
        let a = String(repeating: "a", count: 40), b = String(repeating: "b", count: 40)
        #expect(throws: DeskError.self) { try ComparisonPair(base: a, target: a) }
        #expect(throws: DeskError.self) { try ComparisonPair(base: "--help", target: b) }
        let pair = try ComparisonPair(base: a, target: b)
        #expect(try pair.reversed().base == b)
        #expect(ComparisonPair.validOID(String(repeating: "a", count: 64)))
    }
    @Test func porcelainPreservesBytesAndSpecialNames() {
        var data = Data("# branch.oid (initial)\0# branch.head main\0".utf8)
        data.append(Data("1 M. N... 100644 100644 100644 a b -archivo\ncon espacio.txt\0".utf8))
        data.append(Data("? ".utf8)); data.append(contentsOf: [255, 254]); data.append(0)
        let state = GitParsers.status(data)
        #expect(state.head.isEmpty)
        #expect(state.branch == "main")
        #expect(state.files.count == 2)
        #expect(state.files[0].staged)
        #expect(state.files[0].name == "-archivo\ncon espacio.txt")
        #expect(state.files[1].path == Data([255, 254]))
    }
    @Test func inventoryKeepsRenamesAndBinaryEntries() throws {
        let files = try GitParsers.changes(Data("R100\0old name\0new name\0M\0binary.dat\0".utf8))
        #expect(files.count == 2)
        #expect(files[0].oldPath == Data("old name".utf8))
        #expect(files[0].name == "new name")
        #expect(files[1].name == "binary.dat")
    }
    @Test func terminalHandlesUTF8SplitAndRejectsNativeActions() {
        var terminal = TerminalScreen()
        let bytes = Data("á😀".utf8)
        terminal.consume(bytes.prefix(1)); terminal.consume(bytes.dropFirst(1))
        terminal.consume(Data("\u{1b}]52;c;clipboard-content\u{7} visible".utf8))
        #expect(terminal.output.contains("á😀"))
        #expect(terminal.output.contains("visible"))
        #expect(!terminal.output.contains("clipboard-content"))
    }
    @Test func providerRefusesCredentialExfiltrationURLs() {
        #expect(BitbucketClient.validAPIURL(URL(string: "https://api.bitbucket.org/2.0/user/workspaces")!))
        #expect(!BitbucketClient.validAPIURL(URL(string: "https://api.bitbucket.org.attacker.invalid/2.0/x")!))
        #expect(!BitbucketClient.validAPIURL(URL(string: "https://user:secret@api.bitbucket.org/2.0/x")!))
        #expect(!BitbucketClient.validAPIURL(URL(string: "http://api.bitbucket.org/2.0/x")!))
    }
}
