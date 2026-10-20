// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "BadgerCore",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "BadgerCore", targets: ["BadgerCore"]),
    ],
    targets: [
        .target(name: "BadgerCore"),
        .testTarget(name: "BadgerCoreTests", dependencies: ["BadgerCore"]),
    ]
)
