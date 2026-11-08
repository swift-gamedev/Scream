# Scream

Idiomatic Swift bindings for [Flecs](https://www.flecs.dev), the entity component system, for
Linux, Windows, macOS and the web.

Flecs is compiled into your program by Swift Package Manager, so Flecs itself needs no install;
you need a Swift toolchain and nothing else. The name comes from a group of swifts sometimes being
called a "screaming party". Scream is the sibling of [Swaylib](https://github.com/swift-gamedev/Swaylib),
which does the same for raylib, and the two work together without depending on each other.

```swift
import Scream

struct Position { var x: Double, y: Double }
struct Velocity { var x: Double, y: Double }

let world = World()
world.system(InOut<Position>.self, In<Velocity>.self, name: "Move") { position, velocity in
    position.x += velocity.x
    position.y += velocity.y
}

let entity = world.entity("Bob")
world.set(entity, Position(x: 0, y: 0))
world.set(entity, Velocity(x: 1, y: 2))

while world.progress() {}
```

Components are plain Swift types, registered the first time a world sees them. Queries and systems
are typed, with the access mode in the type so Flecs can schedule them, and iterate within a small
factor of the C API. The world owns everything and destroys it when it goes out of scope. The names
follow Flecs', so its documentation still applies.

## Use it

```swift
dependencies: [
    .package(url: "https://github.com/swift-gamedev/Scream.git", branch: "main"),
],
```

Needs Swift 6.2 or newer. On Windows, install the Visual Studio components that the
[Swift installation instructions](https://www.swift.org/install/windows/) list. For the web, install
the Swift SDK for Wasm from the same page and build with `--swift-sdk`.

## Try the examples

Flecs is a git submodule, so clone with `--recurse-submodules` (SwiftPM does that for you when
Scream is a dependency). The console examples print and exit:

```
swift run HelloWorld
swift run Hierarchy
swift run Observers
```

They run on the web too: build one with `--swift-sdk swift-6.4.2-RELEASE_wasm --product HelloWorld`
and run the `.wasm` with `node Examples/run-wasm.mjs`.

Two more draw a world with [Swaylib](https://github.com/swift-gamedev/Swaylib). They live in their
own package, so Scream never depends on Swaylib:

```
cd Examples/SwaylibExamples
swift run BouncingBalls
swift run SolarSystem
```

Those need the X11 and OpenGL headers on Linux, as Swaylib's README says, and honor
`SWAYLIB_FRAMES=60 SWAYLIB_SCREENSHOT=out.png` to draw 60 frames, save a screenshot and exit.

## Documentation

The DocC catalog in `Sources/Scream/Scream.docc/` has a getting started guide, the threading
model, the architecture, a roadmap, and a generated page listing which of Flecs' functions are
wrapped. Build it locally with `swift package generate-documentation --target Scream`.

## Status

An MVP: entities, components, pairs, hierarchies, prefabs, typed queries, systems (including
multi-threaded ones), observers and Flecs' log, with examples, tested on Linux in debug and release
and under the sanitizers; Windows, macOS and Wasm build and run the examples on CI but have not
been checked by a person yet. See
the roadmap in the docs, and `AGENTS.md` for the design.

## License

MIT, like Flecs. See `LICENSE`. Flecs' own license is in its submodule under `Sources/CFlecs/flecs/`.
