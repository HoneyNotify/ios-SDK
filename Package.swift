// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HoneyNotify",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(name: "HoneyNotify", targets: ["HoneyNotify"]),
    ],
    targets: [
        .target(name: "HoneyNotify"),
        .testTarget(name: "HoneyNotifyTests", dependencies: ["HoneyNotify"]),
    ]
)
