// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GDKSwift",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "GDKSwift",
            targets: ["GDKSwift"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Flight-School/AnyCodable.git", from: "0.6.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "GDKSwift",
            dependencies: [
                "AnyCodable"
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "GDKSwiftTests",
            dependencies: [
                "GDKSwift",
                "AnyCodable"
            ],
            resources: [
                .process("Resources")
            ]
        ),
    ]
)
