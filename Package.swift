// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FeatureFlow",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8)
    ],
    products: [
        .library(
            name: "FeatureFlow",
            targets: ["FeatureFlow"]
        ),
        .library(
            name: "FeatureFlowTesting",
            targets: ["FeatureFlowTesting"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "FeatureFlow"
        ),
        .target(
            name: "FeatureFlowTesting",
            dependencies: ["FeatureFlow"]
        ),
        .testTarget(
            name: "FeatureFlowTests",
            dependencies: ["FeatureFlow", "FeatureFlowTesting"]
        ),
    ]
)
