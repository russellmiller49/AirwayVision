// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AirwayVision",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "AirwayVision", targets: ["AirwayVision"])
    ],
    dependencies: [
        .package(url: "https://github.com/dehesa/swift-csv.git", from: "0.6.0")
    ],
    targets: [
        .target(
            name: "AirwayVision",
            dependencies: [
                .product(name: "CodableCSV", package: "swift-csv")
            ],
            path: "",
            exclude: ["README.md", "PrebuiltModels/README.md"],
            sources: ["ApplicationCore", "Model", "UserInterface"]
        ),
        .testTarget(
            name: "AirwayVisionTests",
            dependencies: ["AirwayVision"],
            path: "AirwayVisionTests"
        )
    ]
)
