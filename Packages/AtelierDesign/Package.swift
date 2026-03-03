// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AtelierDesign",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(name: "AtelierDesign", targets: ["AtelierDesign"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.5.0"),
    ],
    targets: [
        .target(
            name: "AtelierDesign",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
            ],
            resources: [.process("Resources")]
        ),

        .testTarget(
            name: "AtelierDesignTests",
            dependencies: ["AtelierDesign"]
        ),
    ]
)
