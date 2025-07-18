// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OpenFoundationModels-OpenAI",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .tvOS(.v18),
        .watchOS(.v11),
        .visionOS(.v2)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "OpenFoundationModelsOpenAI",
            targets: ["OpenFoundationModelsOpenAI"]),
    ],
    dependencies: [
        // OpenFoundationModels core framework
        .package(url: "https://github.com/1amageek/OpenFoundationModels.git", branch: "main")
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
