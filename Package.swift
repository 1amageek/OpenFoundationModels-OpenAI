// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OpenFoundationModels-OpenAI",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "OpenFoundationModelsOpenAI",
            targets: ["OpenFoundationModelsOpenAI"]),
    ],
    dependencies: [
        // OpenFoundationModels core framework
        .package(url: "https://github.com/1amageek/OpenFoundationModels.git", from: "1.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "OpenFoundationModelsOpenAI",
            dependencies: [
                .product(name: "OpenFoundationModels", package: "OpenFoundationModels")
            ]
        ),
        .testTarget(
            name: "OpenFoundationModelsOpenAITests",
            dependencies: ["OpenFoundationModelsOpenAI"]
        ),
    ]
)
