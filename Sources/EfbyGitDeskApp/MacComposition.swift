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
        let binaryFolder = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
        let helper = binaryFolder.appendingPathComponent("EfbyGitDeskCredential").path
        let adapter = GitAdapter(vault: vault, credentialHelper: helper)
        let cloud = BitbucketClient(vault: vault)
        let service = DeskService(git: adapter, registry: registry, cloud: cloud, discovery: FolderDiscovery())
        return DeskModel(service: service, terminalFactory: { PTYTerminal() })
    }
}
