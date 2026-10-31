// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MenuBarCover",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "CoverCore"),
        .executableTarget(name: "MenuBarCover", dependencies: ["CoverCore"]),
        .testTarget(name: "CoverCoreTests", dependencies: ["CoverCore"]),
    ]
)
