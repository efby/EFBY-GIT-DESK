import Foundation
import EfbyGitDeskInfrastructure

if let reference = ProcessInfo.processInfo.environment["EFBY_CREDENTIAL_OPERATION"],
   let prompt = CommandLine.arguments.dropFirst().first,
   let response = try? KeychainVault.askpass(reference: reference, prompt: prompt) {
    FileHandle.standardOutput.write(Data((response + "\n").utf8))
} else {
    exit(1)
}
