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
    dependencies: [
        .package(path: "../AtelierSecurity"),
    ],
    targets: [
        .target(
            name: "AtelierKit",
            dependencies: [
                .product(name: "AtelierSecurity", package: "AtelierSecurity"),
            ]
        ),

        .testTarget(
            name: "AtelierKitTests",
            dependencies: ["AtelierKit"]
        ),
    ]
)
