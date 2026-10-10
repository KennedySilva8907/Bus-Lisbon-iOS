// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BusLisbonCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "BusLisbonCore", targets: ["BusLisbonCore"]),
    ],
    targets: [
        .target(name: "BusLisbonCore"),
        .testTarget(name: "BusLisbonCoreTests", dependencies: ["BusLisbonCore"]),
    ]
)
