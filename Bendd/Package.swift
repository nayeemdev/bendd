// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Bendd",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "BenddKit",
            resources: [.process("Rendering/Shaders.metal")]
        ),
        .executableTarget(
            name: "Bendd",
            dependencies: ["BenddKit"]
        ),
    ]
)
