// swift-tools-version: 5.9
import PackageDescription

let package = Package(name: "KeyCommand", platforms: [.macOS(.v13)],
    products: [.executable(name: "KeyCommand", targets: ["KeyCommand"])],
    targets: [.target(name: "KeyCommandCore"),
              .executableTarget(name: "KeyCommand", dependencies: ["KeyCommandCore"]),
              .testTarget(name: "KeyCommandCoreTests", dependencies: ["KeyCommandCore"])])
