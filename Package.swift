// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DynamicLanding",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DynamicLanding", targets: ["DynamicLanding"]),
        .executable(name: "DynamicLandingDemo", targets: ["DynamicLandingDemo"]),
    ],
    targets: [
        .target(
            name: "DynamicLanding",
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .executableTarget(name: "DynamicLandingDemo", dependencies: ["DynamicLanding"]),
        .testTarget(name: "DynamicLandingTests", dependencies: ["DynamicLanding"]),
    ],
    swiftLanguageModes: [.v5]
)
