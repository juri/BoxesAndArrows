// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "BoxesAndArrows",
    platforms: [.macOS(.v13)],
    products: [
        .library(
            name: "BoxesAndArrows",
            targets: ["BoxesAndArrows"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-numerics", from: "1.0.0"),
        .package(url: "https://github.com/compnerd/cassowary.git", from: "0.0.1"),
        .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "0.6.1"),
        .package(url: "https://github.com/pointfreeco/swift-parsing.git", from: "0.11.0"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.10.0"),
        .package(url: "https://github.com/pointfreeco/swift-tagged.git", from: "0.8.0"),
    ],
    targets: [
        .target(
            name: "BoxesAndArrows",
            dependencies: [
                .cassowary,
                .tagged,
                "Draw",
                "DrawCocoa",
                "Parser",
            ]
        ),
        .target(
            name: "Draw",
            dependencies: [
                .numerics,
            ]
        ),
        .target(
            name: "DrawCocoa",
            dependencies: [
                "Draw",
            ]
        ),
        .target(
            name: "Parser",
            dependencies: [
                .parsing,
                "Draw",
            ]
        ),
        .testTarget(
            name: "BoxesAndArrowsTests",
            dependencies: [
                .snapshot,
                "BoxesAndArrows",
            ]
        ),
        .testTarget(
            name: "ParserTests",
            dependencies: [
                .customDump,
                .parsing,
                "Draw",
                "Parser",
            ]
        ),
    ]
)

extension PackageDescription.Target.Dependency {
    static let cassowary: PackageDescription.Target.Dependency = .product(name: "cassowary", package: "cassowary")
    static let customDump: PackageDescription.Target.Dependency = .product(name: "CustomDump", package: "swift-custom-dump")
    static let numerics: PackageDescription.Target.Dependency = .product(name: "Numerics", package: "swift-numerics")
    static let parsing: PackageDescription.Target.Dependency = .product(name: "Parsing", package: "swift-parsing")
    static let snapshot: PackageDescription.Target.Dependency = .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
    static let tagged: PackageDescription.Target.Dependency = .product(name: "Tagged", package: "swift-tagged")
}
