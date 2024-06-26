// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "swift-combine-extras",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
        .macOS(.v10_15),
        .macCatalyst(.v13)
    ],
    products: [
        .library(name: "CombineExtras", targets: ["CombineExtras"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-concurrency-extras",
            from: Version(1, 0, 0)
        )
    ],
    targets: [
        .target(name: "CombineExtras", dependencies: [
            .product(name: "ConcurrencyExtras", package: "swift-concurrency-extras")
        ])
    ]
)
