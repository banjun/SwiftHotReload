// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftHotReload",
    platforms: [.iOS(.v14), .macOS(.v13)],
    products: [
        .library(name: "SwiftHotReload", targets: ["SwiftHotReload"]),
    ],
    targets: [
        .target(
            name: "SwiftHotReload",
            path: "Sources",
            swiftSettings: [.define("DEBUG", .when(configuration: .debug))]
        ),
        .executableTarget(
            name: "BuildHelper",
            dependencies: ["SwiftHotReload"],
            path: "BuildHelper/Sources"
        ),
        .testTarget(name: "SwiftHotReloadTests", dependencies: ["SwiftHotReload"]),
    ]
)
