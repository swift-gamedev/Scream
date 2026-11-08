// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Scream",
    platforms: [
        // The tools in this package use URL and clock APIs that need macOS 13.
        .macOS(.v13)
    ],
    products: [
        .library(name: "Scream", targets: ["Scream"])
    ],
    dependencies: [
        // Builds the DocC catalog with `swift package generate-documentation`.
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.5.0")
    ],
    targets: [
        // Flecs' own source, a git submodule at a tagged release under flecs/. flecs.c at the top
        // level of the target includes the amalgamated flecs/distr/flecs.c, so the submodule itself
        // is never compiled directly. Configuration macros live in include/CFlecs.h, which both the
        // C compile and the Swift importer read; a define here would reach only the C compile.
        .target(
            name: "CFlecs",
            exclude: ["flecs"],
            sources: ["flecs.c"],
            cSettings: [
                // SwiftPM defines nothing for release builds, and Flecs enables its debug checks
                // whenever NDEBUG is missing. This only changes code, not the layout of any struct
                // Swift holds by value; the layout test in ScreamTests checks that.
                .define("NDEBUG", .when(configuration: .release))
            ],
            linkerSettings: [
                .linkedLibrary("m", .when(platforms: [.linux])),
                .linkedLibrary("pthread", .when(platforms: [.linux])),
                .linkedLibrary("rt", .when(platforms: [.linux])),
                // The HTTP addon and the OS API's backtraces. flecs.c also asks for these with
                // #pragma comment(lib), but the Swift driver's link step does not read those.
                .linkedLibrary("Ws2_32", .when(platforms: [.windows])),
                .linkedLibrary("DbgHelp", .when(platforms: [.windows])),
            ]
        ),
        // C helpers for what Swift cannot import: function-like macros, the mutable global
        // ecs_os_api, and the struct sizes the layout test compares against.
        .target(
            name: "CFlecsShims",
            dependencies: ["CFlecs"]
        ),
        .target(
            name: "Scream",
            dependencies: ["CFlecs", "CFlecsShims"]
        ),
        .testTarget(
            name: "ScreamTests",
            dependencies: ["Scream"]
        ),
        // Console examples. Each runs to completion on its own, so CI runs them on every platform,
        // including Wasm under Node. The ones that draw with Swaylib are a separate package in
        // Examples/SwaylibExamples, so this package never depends on Swaylib.
        .executableTarget(name: "HelloWorld", dependencies: ["Scream"], path: "Examples/HelloWorld"),
        .executableTarget(name: "Hierarchy", dependencies: ["Scream"], path: "Examples/Hierarchy"),
        .executableTarget(name: "Observers", dependencies: ["Scream"], path: "Examples/Observers"),
        // Times Scream's query iteration against the same loop written against the C API.
        .executableTarget(
            name: "IterationBenchmark",
            dependencies: ["Scream", "CFlecs"],
            path: "Benchmarks/Iteration"
        ),
        // Writes Sources/Scream/Generated and the API coverage page from the declarations in
        // flecs.h, read through clang's JSON AST dump.
        .executableTarget(
            name: "scream-generate",
            path: "Tools/Generate",
            exclude: ["wrapped.txt"]
        ),
    ],
    cLanguageStandard: .gnu11
)
