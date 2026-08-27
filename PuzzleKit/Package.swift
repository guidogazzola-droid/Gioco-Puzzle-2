// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PuzzleKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PuzzleKit", targets: ["PuzzleKit"])
    ],
    targets: [
        .target(
            name: "PuzzleKit",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "PuzzleKitTests",
            dependencies: ["PuzzleKit"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
