// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CHRemoteMonitor",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "CHShared", targets: ["CHShared"]),
    ],
    targets: [
        .target(
            name: "CHShared",
            path: "Shared"
        ),
        .testTarget(
            name: "CHSharedTests",
            dependencies: ["CHShared"],
            path: "Tests/CHSharedTests"
        ),
    ]
)
