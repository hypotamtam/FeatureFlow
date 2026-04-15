// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

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
        .package(url: "https://github.com/apple/swift-syntax.git", from: "600.0.0"),
    ],
    targets: [
        .macro(
            name: "FeatureFlowMacros",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "FeatureFlow",
            dependencies: ["FeatureFlowMacros"]
        ),
        .target(
            name: "FeatureFlowTesting",
            dependencies: ["FeatureFlow"]
        ),
        .testTarget(
            name: "FeatureFlowTests",
            dependencies: ["FeatureFlow", "FeatureFlowTesting"]
        ),
        .testTarget(
            name: "FeatureFlowMacrosTests",
            dependencies: [
                "FeatureFlowMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
