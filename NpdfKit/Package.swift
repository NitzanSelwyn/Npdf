// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NpdfKit",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "NpdfKit", targets: ["NpdfKit"]),
    ],
    targets: [
        .target(
            name: "NpdfKit",
            dependencies: [],
            path: "Sources/NpdfKit"
        ),
        .testTarget(
            name: "NpdfKitTests",
            dependencies: ["NpdfKit"],
            path: "Tests/NpdfKitTests"
        ),
    ]
)
