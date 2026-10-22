// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AnimeDubStudio",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "AnimeDubStudio",
            targets: ["AnimeDubStudio"]
        ),
        .library(
            name: "AnimeDubCore",
            targets: ["AnimeDubCore"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "AnimeDubCore",
            dependencies: [],
            path: "Sources/AnimeDubCore",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency")
            ]
        ),
        .executableTarget(
            name: "AnimeDubStudio",
            dependencies: ["AnimeDubCore"],
            path: "Sources/AnimeDubStudio",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency")
            ]
        ),
        .testTarget(
            name: "AnimeDubCoreTests",
            dependencies: ["AnimeDubCore"],
            path: "Tests/AnimeDubCoreTests",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency")
            ]
        )
    ]
)
