// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "DesktopPet",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "DesktopPet",
            path: "src/DesktopPet"
        )
    ]
)
