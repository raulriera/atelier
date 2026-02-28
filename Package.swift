// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "Atelier",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "AtelierDesign", targets: ["AtelierDesign"]),
        .library(name: "AtelierKit", targets: ["AtelierKit"]),
    ],
    targets: [
        // MARK: - Design System

        .target(
            name: "AtelierDesign",
            resources: [.process("Resources")]
        ),

        // MARK: - Core Logic

        .target(
            name: "AtelierKit"
        ),

        // MARK: - Tests

        .testTarget(
            name: "AtelierDesignTests",
            dependencies: ["AtelierDesign"]
        ),
        .testTarget(
            name: "AtelierKitTests",
            dependencies: ["AtelierKit"]
        ),
    ]
)
