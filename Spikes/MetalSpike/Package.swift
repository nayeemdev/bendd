// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "metalspike",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "metalspike",
            resources: [.process("Shaders.metal")]
        )
    ]
)
