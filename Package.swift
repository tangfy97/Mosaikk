// swift-tools-version: 5.10
import PackageDescription

// The engine on its own, for tests and command-line checks. The app compiles these sources directly (see project.yml).
let package = Package(
    name: "Mosaikk",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.library(name: "MosaikkCore", targets: ["MosaikkCore"])],
    targets: [
        .target(name: "MosaikkCore"),
        .testTarget(name: "MosaikkCoreTests", dependencies: ["MosaikkCore"]),
    ]
)
