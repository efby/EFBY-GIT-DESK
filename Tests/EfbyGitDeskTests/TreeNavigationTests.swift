import Foundation
import Testing
import EfbyGitDeskDomain
import EfbyGitDeskInfrastructure
@testable import EfbyGitDeskPresentation

struct TreeNavigationTests {
    @Test func folderExpansionRestoresPerRepositoryAndToggleAllPreservesHiddenFolders() async throws {
        let fixture = try await GitFixture.make(); defer { fixture.cleanup() }
        let registry = try SQLiteRegistry(path: fixture.folder.appendingPathComponent("expansion.sqlite").path)
        let first = FolderExpansionPreference.key(scope: "comparison", repositoryID: "/one/project")
        let second = FolderExpansionPreference.key(scope: "comparison", repositoryID: "/two/project")
        #expect(first != second)
        let collapsed: Set<String> = ["folder:src", "folder:hidden"]
        try await registry.setPreference(first, value: #require(FolderExpansionPreference.encode(collapsed)))
        #expect(FolderExpansionPreference.decode(try await registry.preference(first)) == collapsed)
        #expect(FolderExpansionPreference.decode(try await registry.preference(second)).isEmpty)
        let visible: Set<String> = ["folder:src", "folder:test"]
        let expanded = FolderExpansionPreference.toggleAll(collapsed: collapsed, visible: visible)
        #expect(expanded == ["folder:hidden"])
        #expect(FolderExpansionPreference.allExpanded(collapsed: expanded, visible: visible))
        #expect(FolderExpansionPreference.toggleAll(collapsed: expanded, visible: visible) == ["folder:hidden", "folder:src", "folder:test"])
    }

    @Test func indexesPythonTypeScriptAndDartDeclarationsWithoutCommentsOrStrings() {
        let python = """
        # def hidden():
        def first():
            pass
        async def fetch_data():
            pass
        class Reader:
            def read(self):
                pass
        """
        #expect(CodeSymbolIndex.make(text: python, language: .python).map(\.name) == ["first", "fetch_data", "Reader", "read"])
        let typescript = """
        // function hidden() {}
        export async function loadData() {}
        export const refresh = async (id: string) => id;
        class Client {
          public save() { return true; }
        }
        """
        #expect(CodeSymbolIndex.make(text: typescript, language: .typescript).map(\.name) == ["loadData", "refresh", "Client", "save"])
        let dart = """
        /* void hidden() {} */
        Future<String> fetch() async {
          return 'ok';
        }
        class Service {
          void save() => print('ok');
        }
        """
        #expect(CodeSymbolIndex.make(text: dart, language: .dart).map(\.name) == ["fetch", "Service", "save"])
        #expect(CodeLanguage.detect(path: "lib/service.dart") == .dart)
        #expect(CodeSymbolIndex.make(text: String(repeating: "x", count: 2_000_001), language: .dart).isEmpty)
    }
}
