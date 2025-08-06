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
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.2.0")
    ],
    targets: [
        .executableTarget(
            name: "UVManager",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ],
            path: "UVManager",
            resources: [
                .process("Assets.xcassets"),
                .process("Preview Content")
            ]
        )
    ]
)
