// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "media-metadata-viewer",
    platforms: [
        .macOS(.v11),
    ],
    dependencies: [
        .package(id: "apple.swift-argument-parser", exact: "1.7.1"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "media-metadata-viewer",
            dependencies: [
                .product(name: "ArgumentParser", package: "apple.swift-argument-parser"),
            ],
            linkerSettings: [
                .linkedFramework("ImageIO"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("UniformTypeIdentifiers"),
            ]),
    ]
)
