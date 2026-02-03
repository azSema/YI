// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "YI",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "YI",
            targets: ["YI"]
        ),
    ],
    targets: [
        .target(
            name: "YI"
        ),
        .testTarget(
            name: "YITests",
            dependencies: ["YI"]
        ),
    ]
)
