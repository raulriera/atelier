// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "AtelierSecurity",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "AtelierSecurity", targets: ["AtelierSecurity"]),
    ],
    targets: [
        .target(
            name: "AtelierSecurity",
            linkerSettings: [
                .linkedFramework("Security"),
            ]
        ),

        .testTarget(
            name: "AtelierSecurityTests",
            dependencies: ["AtelierSecurity"]
        ),
    ]
)
