// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftHotReload",
    platforms: [.iOS(.v14), .macOS(.v13), .visionOS(.v1)],
    products: [
        .library(name: "SwiftHotReload", targets: ["SwiftHotReload"]),
    ],
    targets: [
        .target(name: "SwiftHotReload"),
        .testTarget(name: "SwiftHotReloadTests", dependencies: ["SwiftHotReload"]),
    ]
)
