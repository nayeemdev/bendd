// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "screenshotspike",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "screenshotspike")
    ]
)
