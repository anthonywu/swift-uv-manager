// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "UVManager",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "UVManager",
            targets: ["UVManager"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "UVManager",
            dependencies: [],
            path: "UVManager",
            resources: [
                .process("Assets.xcassets"),
                .process("Preview Content")
            ]
        )
    ]
)
