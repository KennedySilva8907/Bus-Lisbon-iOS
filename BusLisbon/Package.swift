// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BusLisbon",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "BusLisbon", targets: ["BusLisbon"]),
    ],
    dependencies: [
        .package(path: "../BusLisbonCore"),
    ],
    targets: [
        .target(
            name: "BusLisbon",
            dependencies: [.product(name: "BusLisbonCore", package: "BusLisbonCore")],
            resources: [.copy("Resources/splash-hero.jpg"), .copy("Resources/stop-pin.png"), .copy("Resources/bus-marker.png")]
        ),
    ]
)
