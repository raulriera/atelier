// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MCPHelperKit",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(name: "MCPHelperKit", targets: ["MCPHelperKit"]),
    ],
    targets: [
        .target(name: "MCPHelperKit"),

        .testTarget(
            name: "MCPHelperKitTests",
            dependencies: ["MCPHelperKit"]
        ),
    ]
)
