import Foundation
import EfbyGitDeskApplication
import EfbyGitDeskInfrastructure
import EfbyGitDeskPresentation

@MainActor enum MacComposition {
    static func makeModel() throws -> DeskModel {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("EfbyGitDesk")
        let registry = try SQLiteRegistry(path: folder.appendingPathComponent("catalog.sqlite").path)
        let vault = KeychainVault()
        let locations = ["/opt/homebrew/bin/git", "/usr/local/bin/git", "/usr/bin/git"]
        guard let git = locations.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw NSError(domain: "EfbyGitDesk", code: 1, userInfo: [NSLocalizedDescriptionKey: "Instala Git antes de abrir la aplicación."])
        }
        let binaryFolder = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
        let helper = binaryFolder.appendingPathComponent("EfbyGitDeskCredential").path
        let adapter = GitAdapter(executable: git, vault: vault, credentialHelper: helper)
        let cloud = BitbucketClient(vault: vault)
        let service = DeskService(git: adapter, registry: registry, cloud: cloud)
        return DeskModel(service: service, terminalFactory: { PTYTerminal() })
    }
}
