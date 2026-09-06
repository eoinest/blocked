// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Blocked",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "BlockedKey", targets: ["BlockedKey"])],
    targets: [
        .target(name: "BlockedCore"),
        .executableTarget(name: "BlockedKey", dependencies: ["BlockedCore"]),
        .testTarget(name: "BlockedCoreTests", dependencies: ["BlockedCore"])
    ]
)
