import Foundation
import Testing
import EfbyGitDeskDomain
@testable import EfbyGitDeskPresentation

@Suite struct CursorComparisonPromptTests {
    @Test func promptURLStaysWithinCursorDeeplinkLimit() throws {
        let pair = try ComparisonPair(base: String(repeating: "a", count: 40), target: String(repeating: "b", count: 40))
        let paths = (0..<200).map { "Sources/File\($0).swift" }
        let prompt = CursorComparisonPrompt.make(pair: pair,
                                                 baseMessage: "antes",
                                                 targetMessage: "después",
                                                 repositoryName: "repo",
                                                 changedFilePaths: paths)
        let url = try #require(CursorPromptLink.promptURL(for: prompt))
        #expect(url.absoluteString.count <= 10_000)
        #expect(url.scheme == "cursor")
    }

    @Test func promptListsAllChangedFilesWithoutDiff() throws {
        let pair = try ComparisonPair(base: String(repeating: "1", count: 40), target: String(repeating: "2", count: 40))
        let prompt = CursorComparisonPrompt.make(pair: pair,
                                                 baseMessage: "init",
                                                 targetMessage: "docs",
                                                 repositoryName: "repo",
                                                 changedFilePaths: ["README.md", "src/handler.py"])
        #expect(prompt.contains(String(pair.base.prefix(8))))
        #expect(prompt.contains(String(pair.target.prefix(8))))
        #expect(prompt.contains("Archivos modificados (2):"))
        #expect(prompt.contains("- README.md"))
        #expect(prompt.contains("- src/handler.py"))
        #expect(!prompt.contains("diff --git"))
    }
}
