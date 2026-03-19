// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VaultApp",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "VaultApp",
            path: "Sources"
        )
    ]
)
