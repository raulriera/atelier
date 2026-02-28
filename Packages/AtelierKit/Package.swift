// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "AtelierKit",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "AtelierKit", targets: ["AtelierKit"]),
    ],
    targets: [
        .target(
            name: "AtelierKit"
        ),

        .testTarget(
            name: "AtelierKitTests",
            dependencies: ["AtelierKit"]
        ),
    ]
)
