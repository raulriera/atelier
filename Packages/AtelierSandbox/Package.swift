// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AtelierSandbox",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(name: "AtelierSandbox", targets: ["AtelierSandbox"]),
    ],
    dependencies: [
        .package(path: "../AtelierSecurity"),
    ],
    targets: [
        .target(
            name: "AtelierSandbox",
            dependencies: ["AtelierSecurity"]
        ),

        .testTarget(
            name: "AtelierSandboxTests",
            dependencies: ["AtelierSandbox"]
        ),
    ]
)
