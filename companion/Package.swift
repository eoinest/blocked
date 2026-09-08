// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Blocked",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "BlockedKey", targets: ["BlockedKey"]),
               .executable(name: "ButtonTester", targets: ["ButtonTester"])],
    targets: [
        .target(name: "BlockedCore"),
        .executableTarget(name: "BlockedKey", dependencies: ["BlockedCore"]),
        .testTarget(name: "BlockedCoreTests", dependencies: ["BlockedCore"]),
        .target(name: "ButtonTestCore"),
        .executableTarget(name: "ButtonTester", dependencies: ["ButtonTestCore"]),
        .testTarget(name: "ButtonTestCoreTests", dependencies: ["ButtonTestCore"])
    ]
)
