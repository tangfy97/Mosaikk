// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CollageAtelier",
    platforms: [.macOS(.v14)],
    products: [.library(name: "AtelierCore", targets: ["AtelierCore"])],
    targets: [
        .target(name: "AtelierCore"),
        .testTarget(name: "AtelierCoreTests", dependencies: ["AtelierCore"])
    ],
    swiftLanguageModes: [.v6]
)
