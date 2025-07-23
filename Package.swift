// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AirwayVision",
    platforms: [
        .visionOS("1.0")
    ],
    products: [
        .library(name: "AirwayVision", targets: ["AirwayVision"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftcsv/SwiftCSV.git", from: "0.6.0")
    ],
    targets: [
        .target(
            name: "AirwayVision",
            dependencies: ["SwiftCSV"],
            path: ".",
            exclude: ["Tests", "README.md"]
        ),
        .testTarget(
            name: "AirwayVisionTests",
            dependencies: ["AirwayVision"],
            path: "Tests"
        )
    ]
)
