// swift-tools-version: 6.2

// Examples that draw a Scream world with Swaylib. They are a separate package so that Scream
// itself never depends on Swaylib or on the X11 and OpenGL headers it needs on Linux.
import PackageDescription

let package = Package(
    name: "ScreamSwaylibExamples",
    platforms: [
        // Swaylib needs macOS 15.
        .macOS(.v15)
    ],
    dependencies: [
        .package(name: "Scream", path: "../.."),
        .package(url: "https://github.com/swift-gamedev/Swaylib.git", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "BouncingBalls",
            dependencies: [
                .product(name: "Scream", package: "Scream"),
                .product(name: "Swaylib", package: "Swaylib"),
            ]
        ),
        .executableTarget(
            name: "SolarSystem",
            dependencies: [
                .product(name: "Scream", package: "Scream"),
                .product(name: "Swaylib", package: "Swaylib"),
            ]
        ),
    ]
)
