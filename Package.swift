// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Tetris",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "TetrisCore",
            targets: ["TetrisCore"]
        ),
        .executable(
            name: "TetrisApp",
            targets: ["TetrisApp"]
        )
    ],
    targets: [
        .target(
            name: "TetrisCore"
        ),
        .executableTarget(
            name: "TetrisApp",
            dependencies: ["TetrisCore"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "TetrisCoreTests",
            dependencies: ["TetrisCore"]
        ),
        .testTarget(
            name: "TetrisAppTests",
            dependencies: ["TetrisApp"]
        )
    ]
)
