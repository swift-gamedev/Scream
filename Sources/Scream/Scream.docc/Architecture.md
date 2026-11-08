# Architecture

How the package is put together, from Flecs' C source up to the Swift API.

## Overview

The package has three layers, each a SwiftPM target, plus the generator that writes the mechanical
parts of the top one.

## CFlecs

Flecs' own repository is a git submodule at a tagged release under `Sources/CFlecs/flecs/`, so its
files are never touched and the pinned commit is the version. SwiftPM never compiles the submodule
directly. The wrapper `flecs.c` at the top of the target includes the amalgamated
`flecs/distr/flecs.c`, after the umbrella header `include/CFlecs.h`, which includes
`flecs/distr/flecs.h` and sets Flecs' configuration macros.

Those macros live in the header and not in `Package.swift` for a reason: a define in a target's
`cSettings` reaches that target's C compile only, while the Swift compiler importing the module
reads the header without it. Anything that changes what `flecs.h` declares, such as the addon
selection, has to be visible to both, so it goes in `CFlecs.h`. Conditions on the target work there
too; this is how the HTTP and REST addons are turned off for Wasm, where there are no sockets.

The one define that is in `Package.swift` is `NDEBUG` for release builds, because SwiftPM does not
set it and Flecs turns on its debug checks whenever it is missing. Swift still imports the debug
layout, so a Flecs struct whose size depends on `NDEBUG` must never be held by value in Swift; the
layout test in `ScreamTests` compares Swift's `MemoryLayout` with sizes exported from C for every
struct that is.

Updating Flecs means moving the submodule to the new tag, regenerating, and fixing whatever
changed.

## CFlecsShims

C functions for what Swift cannot import: Flecs' function-like macros (`ecs_pair` and friends) as
`static inline` functions, the mutable global `ecs_os_api` for the log handler, and the struct sizes
the layout test reads.

## Scream

The Swift API. ``World`` is a noncopyable struct that owns an `ecs_world_t` and destroys it in
`deinit`. ``Entity`` is a plain 64-bit id, `Hashable` and `Sendable`, that holds no pointer to its
world.

`Sources/Scream/Generated/` holds Flecs' enums and builtin entities, written by the generator.
Everything else is by hand.

## The generator

Flecs publishes no machine-readable description of its API, so `swift run scream-generate` runs the
clang from the Swift toolchain over the umbrella header with `-ast-dump=json` and reads the
declarations from that: the enums become Swift enums with Flecs' values, every
`extern const ecs_entity_t Ecs...` becomes a static member of ``Entity``, and every function goes
on the <doc:APICoverage> page under its Doxygen group, with the Swift symbol from
`Tools/Generate/wrapped.txt`. With `--check` it only reports whether the committed files are up to
date, which CI uses. Because the header has platform conditionals, the committed output is the one
generated on Linux.
