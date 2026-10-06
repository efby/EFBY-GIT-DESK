// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "EfbyGitDesk",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "EfbyGitDesk", targets: ["EfbyGitDeskApp"]),
        .executable(name: "EfbyGitDeskCredential", targets: ["EfbyGitDeskCredential"])
    ],
    targets: [
        .target(name: "EfbyGitDeskDomain"),
        .target(name: "EfbyGitDeskApplication", dependencies: ["EfbyGitDeskDomain"]),
        .systemLibrary(name: "CSQLite", pkgConfig: "sqlite3"),
        .target(name: "CPTY", publicHeadersPath: "include"),
        .target(name: "EfbyGitDeskInfrastructure", dependencies: [
            "EfbyGitDeskApplication", "EfbyGitDeskDomain", "CSQLite", "CPTY"
        ], linkerSettings: [.linkedFramework("Security")]),
        .target(name: "EfbyGitDeskPresentation", dependencies: [
            "EfbyGitDeskApplication", "EfbyGitDeskDomain"
        ]),
        .executableTarget(name: "EfbyGitDeskApp", dependencies: [
            "EfbyGitDeskPresentation", "EfbyGitDeskInfrastructure", "EfbyGitDeskApplication"
        ]),
        .executableTarget(name: "EfbyGitDeskCredential", dependencies: ["EfbyGitDeskInfrastructure"]),
        .testTarget(name: "EfbyGitDeskTests", dependencies: [
            "EfbyGitDeskDomain", "EfbyGitDeskApplication", "EfbyGitDeskInfrastructure"
        ])
    ],
    swiftLanguageModes: [.v6]
)
