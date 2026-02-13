// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "DesktopPet",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "DesktopPet",
            targets: ["DesktopPet"]
        )
    ],
    targets: [
        .executableTarget(
            name: "DesktopPet",
            path: "Sources"
        )
    ]
)
