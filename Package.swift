// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BoxesAndArrows",
    platforms: [.macOS(.v13)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "BoxesAndArrows",
            targets: ["BoxesAndArrows"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/compnerd/cassowary.git", from: "0.0.1"),
        .package(url: "https://github.com/pointfreeco/swift-parsing.git", from: "0.11.0"),
        .package(url: "https://github.com/pointfreeco/swift-tagged.git", from: "0.8.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "BoxesAndArrows",
            dependencies: [
                .cassowary,
                .tagged,
                "Draw",
                "DrawCocoa",
            ]
        ),
        .target(
            name: "Draw",
            dependencies: []
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
            dependencies: ["BoxesAndArrows"]
        ),
        .testTarget(
            name: "ParserTests",
            dependencies: [
                .parsing,
                "Draw",
                "Parser",
            ]
        ),
    ]
)

extension PackageDescription.Target.Dependency {
    static let cassowary: PackageDescription.Target.Dependency = .product(name: "cassowary", package: "cassowary")
    static let parsing: PackageDescription.Target.Dependency = .product(name: "Parsing", package: "swift-parsing")
    static let tagged: PackageDescription.Target.Dependency = .product(name: "Tagged", package: "swift-tagged")
}
