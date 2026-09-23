// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ResolveAIMusic",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "ResolveAIMusic", targets: ["ResolveAIMusic"])],
    targets: [
        .executableTarget(name: "ResolveAIMusic", resources: [.copy("Resources")]),
        .testTarget(name: "ResolveAIMusicTests", dependencies: ["ResolveAIMusic"])
    ]
)
