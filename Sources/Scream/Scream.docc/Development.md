# Development

Building, testing and contributing to Scream itself.

## Building

Flecs is a git submodule, so clone with `git clone --recurse-submodules`, or run
`git submodule update --init` in an existing clone. SwiftPM does this itself when Scream is used
as a dependency.

`swift build` builds Flecs and the package. The toolchain version is pinned in `.swift-version`,
which [swiftly](https://www.swift.org/swiftly/) reads, and CI uses the same version on every
platform. For the web, install the Swift SDK for Wasm of the same version from
[swift.org](https://www.swift.org/install/) and build with
`swift build --swift-sdk swift-6.4.2-RELEASE_wasm --product Scream` (the generator does not build
there, so name the product).

## Testing

`swift test` runs the Swift Testing suites. CI also runs them in release, where the C side sees
`NDEBUG` and Swift does not, so the layout test catches a struct whose size changes, and under the
address and thread sanitizers (`swift test --sanitize=address`, `--sanitize=thread`), which
anything touching hooks, callbacks or threads must pass.

## Formatting and linting

`swift format` ships with the toolchain and reads `.swift-format` at the root:

```
swift format --in-place --recursive Sources/Scream Tools Tests Package.swift
swift format lint --strict --recursive Sources/Scream Tools Tests Package.swift
```

The Flecs submodule is never formatted.

## Generated code

After editing `Tools/Generate/` or `wrapped.txt`, or moving the submodule, run
`swift run scream-generate` on Linux and commit the output. It needs `clang`, which the Swift
toolchain ships; set `SCREAM_CLANG` if it is not found. `swift run scream-generate --check` fails
if the committed output is stale; CI runs it.

## Documentation

Every public symbol has a `///` comment and the articles live in `Sources/Scream/Scream.docc/`.
Build the docs with the Swift-DocC plugin:

```
swift package generate-documentation --target Scream --warnings-as-errors
```

CI runs that command, so a broken symbol link fails the build. To browse them locally:

```
swift package --disable-sandbox preview-documentation --target Scream
```

Every push to `main` publishes the docs to
[swift-gamedev.github.io/Scream](https://swift-gamedev.github.io/Scream/) through the Docs
workflow (`.github/workflows/docs.yml`).

## Adding Flecs API

1. Write the Swift wrapper next to the related code in `Sources/Scream/`, with a doc comment.
2. Add a line to `Tools/Generate/wrapped.txt` for each Flecs function it replaces and regenerate.
3. Cover it with a test, or use it in an example.
4. If it introduces a public type, list it under a topic in `Scream.docc/Scream.md`.
