import Foundation

// scream-generate: writes the mechanical parts of the Swift API from flecs.h.
//
//   swift run scream-generate           regenerate the files under Sources/Scream
//   swift run scream-generate --check   exit 1 if the committed files are out of date
//
// It parses the umbrella header with the clang from the Swift toolchain (or SCREAM_CLANG), so the
// output matches the Flecs being built and the configuration the Swift importer sees. Run it on
// Linux: flecs.h has platform conditionals, and the committed output is the Linux one.

let packageRoot = URL(filePath: #filePath)
    .deletingLastPathComponent()  // main.swift
    .deletingLastPathComponent()  // Generate
    .deletingLastPathComponent()  // Tools
let toolDirectory = packageRoot.appending(path: "Tools/Generate")
let umbrellaHeader = packageRoot.appending(path: "Sources/CFlecs/include/CFlecs.h")
let wrappedFile = toolDirectory.appending(path: "wrapped.txt")

let outputs: [(path: String, content: () throws -> String)] = [
    ("Sources/Scream/Generated/Enums.swift", { emitEnums(api) }),
    ("Sources/Scream/Generated/Builtins.swift", { emitBuiltins(api) }),
    ("Sources/Scream/Scream.docc/APICoverage.md", { try emitCoverage(api, wrapped: wrapped, version: version) }),
]

let check = CommandLine.arguments.contains("--check")

let api: API
let wrapped: [String: String]
let version: String
do {
    api = try API.load(header: umbrellaHeader, clang: try findClang())
    wrapped = try parseWrapped(try String(contentsOf: wrappedFile, encoding: .utf8), api: api)
    version = try flecsVersion()
} catch {
    fail("scream-generate: \(error)")
}

var outOfDate: [String] = []
for output in outputs {
    let url = packageRoot.appending(path: output.path)
    do {
        let content = try output.content()
        let existing = try? String(contentsOf: url, encoding: .utf8)
        if check {
            if existing != content {
                outOfDate.append(output.path)
            }
        } else if existing != content {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try content.write(to: url, atomically: true, encoding: .utf8)
            print("wrote \(output.path)")
        } else {
            print("unchanged \(output.path)")
        }
    } catch {
        fail("scream-generate: \(output.path): \(error)")
    }
}

if !outOfDate.isEmpty {
    fail(
        "scream-generate: out of date, run `swift run scream-generate`:\n"
            + outOfDate.map { "  \($0)" }.joined(separator: "\n"))
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

/// The release the submodule is at, from the version macros in flecs.h.
func flecsVersion() throws -> String {
    let header = packageRoot.appending(path: "Sources/CFlecs/flecs/distr/flecs.h")
    let text = try String(contentsOf: header, encoding: .utf8)
    var parts: [String] = []
    for component in ["MAJOR", "MINOR", "PATCH"] {
        let marker = "#define FLECS_VERSION_\(component) "
        guard let range = text.range(of: marker) else {
            throw GenerateError("FLECS_VERSION_\(component) missing from flecs.h")
        }
        let rest = text[range.upperBound...].prefix(while: \.isNumber)
        parts.append(String(rest))
    }
    return parts.joined(separator: ".")
}
