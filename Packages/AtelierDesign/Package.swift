// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "AtelierDesign",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "AtelierDesign", targets: ["AtelierDesign"]),
    ],
    targets: [
        .target(
            name: "AtelierDesign",
            resources: [.process("Resources")]
        ),

        .testTarget(
            name: "AtelierDesignTests",
            dependencies: ["AtelierDesign"]
        ),
    ]
)
