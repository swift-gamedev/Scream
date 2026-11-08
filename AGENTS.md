# Scream

## Overview

Scream is a set of idiomatic Swift bindings for [Flecs](https://github.com/SanderMertens/flecs), the entity component system. The name comes from a group of swifts sometimes being called a "screaming party". It is the sibling of [Swaylib](https://github.com/swift-gamedev/Swaylib), which does the same job for raylib, and it follows the same conventions unless this file says otherwise. It is cross platform first: Linux, Windows and macOS are all first-class targets, and nothing may assume Apple frameworks or Darwin APIs. The web is a goal too, through Swift's Wasm SDK (see Platform support). Swift Package Manager is the only build system. License: MIT, the same as Flecs (`LICENSE` at the root). Third-party code comes in as a git submodule with its own license, never as a copy, and nothing under a stricter license (GPL, LGPL) may be added.

**Status:** the core exists. Flecs 4.2.0 builds from a git submodule with SwiftPM on Linux, macOS, Windows and Wasm; the generator writes the enums, builtin entities and API coverage page; `World`, `Stage`, `Entity`, `Id`, `Pair` and `Component` cover entities, components, tags, pairs, hierarchies, prefabs, singletons and lifecycle hooks, with tests passing in debug, release and under ASan. Queries, systems and observers come next. When code changes what this file says, or a design here turns out to be wrong, update this file in the same change.

Goals:

- Swift that reads like Swift, not like C with a Swift accent. Users should not need to know Flecs' C API to use Scream, but someone who knows Flecs should find every concept where they expect it.
- Full coverage of the Flecs core: entities, components, tags, pairs and relationships, queries, systems, pipelines, observers, prefabs, hierarchies and modules. Addons follow where they make sense from Swift (REST for the Flecs Explorer, JSON, reflection, script, timers, stats).
- Component iteration fast enough that nobody needs to drop to the C API for performance. Measured, not assumed.
- The same Swift code builds and runs on every supported platform with no `#if os(...)` in user code.
- The web, through Swift's Wasm SDK, without Emscripten.

Non-goals (for now): mobile, and replacing Flecs' C code with Swift. Scream wraps Flecs; it does not reimplement it. Scream also has no renderer, window or game loop. Using it next to Swaylib must work, but neither package depends on the other.

## Layout

- `Sources/CFlecs/`: Flecs' repository as a shallow git submodule under `flecs/`, pinned to a release tag; the pinned commit is the version and the license is inside. SwiftPM never compiles `flecs/` directly: the wrapper `flecs.c` includes the amalgamated `flecs/distr/flecs.c`, and `include/CFlecs.h` is the umbrella header that sets Flecs' configuration macros and includes `flecs/distr/flecs.h` by relative path. Never modify the submodule; anything we need to change goes into a wrapper or a shim. Updating Flecs is: move the submodule to the new tag, regenerate, fix what broke. There is deliberately no option to link a system Flecs: the bindings are tied to one release.
- `Sources/CFlecsShims/`: C helpers for what Swift cannot call or import. Function-like macros such as `ecs_pair` become `static inline` functions here, so their definitions stay next to the C and cannot drift from it. Access to the mutable global `ecs_os_api` also lives here.
- `Sources/Scream/`: the Swift API. `Generated/` is written by the generator and never edited by hand. `Scream.docc/` is the DocC catalog.
- `Tools/Generate/`: the `scream-generate` executable and `wrapped.txt`, the list of Flecs functions that have a Swift counterpart. Flecs publishes no machine-readable API description, so it reads `clang -Xclang -ast-dump=json -fsyntax-only` over the submodule's `flecs.h`, parsed as C.
- `Examples/`: ports of Flecs' examples, one executable target each. Each runs to completion on its own with a fixed number of frames and is a smoke test on CI.
- `Benchmarks/`: iteration and structural-change benchmarks, with the equivalent C loop as the baseline.
- `Tests/ScreamTests/`: Swift Testing suites.
- `.github/workflows/ci.yml`: Linux, macOS, Windows and Wasm, built the same way as Swaylib's: every job reads or checks the toolchain from `.swift-version`, third-party actions are pinned to a commit, the token is read-only and checkouts do not keep credentials. `.github/workflows/docs.yml` publishes the DocC catalog to GitHub Pages on every push to `main`.

The generator emits the mechanical parts: enums and option sets, the builtin entities (`EcsChildOf`, `EcsOnUpdate` and friends), and the API Coverage article, which lists every public Flecs function with the Swift symbol from `wrapped.txt`. Generated output is committed. `swift run scream-generate --check` fails when it is stale, and CI runs that on Linux only, because `flecs.h` has platform conditionals and the output must not depend on who ran it. Only the generator needs `clang`; users of the package do not.

## Flecs integration

These were checked against Flecs 4.2.0 and Swift 6.4.2. Recheck the ones that depend on the version when either moves.

Configuration:

- `.define` in a C target's `cSettings` reaches that target's compile only, not the Swift compiler importing its headers. Anything that changes what `flecs.h` declares (addon selection, `FLECS_CUSTOM_BUILD`, `FLECS_QUERY_PLANS`, `FLECS_USE_OS_ALLOC`, and so on) must be set in `CFlecs.h`, and the wrapper `flecs.c` must include `CFlecs.h` first, so C and Swift see the same declarations. For the same reason, package traits cannot select addons. Conditions on the target, like `#if defined(__wasm__)`, do work in `CFlecs.h`, because C and the importer both compile for the same target.
- SwiftPM does not define `NDEBUG` for release builds, and Flecs turns on `FLECS_DEBUG` whenever it is missing. `CFlecs` needs `.define("NDEBUG", .when(configuration: .release))`, or every release build ships Flecs' debug checks.
- That define does not reach the Swift importer either, so Swift always sees the debug layout of `flecs.h`. Most structs are the same size in both modes, including `ecs_iter_t`, every `*_desc_t`, `ecs_type_hooks_t`, `ecs_type_info_t` and `ecs_term_t`. `ecs_ref_t`, `ecs_map_t`, `ecs_map_iter_t` and `ecs_stack_cursor_t` are not. **Swift code must never hold those four by value, or embed a struct that does.** Allocate them in `CFlecsShims` and pass pointers.
- A layout test compares `MemoryLayout` in Swift against `sizeof` and `alignof` exported from compiled C for every Flecs struct Swift holds by value. Run it in debug and release, and on Wasm as well as 64-bit targets. When adding such a struct, add it there. Never hardcode a struct size or assume `Int` is 64 bits: on wasm32 `Int` is 32 bits and `ecs_iter_t` is 272 bytes rather than 424.
- Never define `FLECS_SANITIZE`. It changes `ecs_vec_t` and the block allocator in the same way and only the C compile would see it.

What Swift cannot import: every function-like macro (`ecs_pair`, `ecs_field`, `ECS_COMPONENT`, `ecs_query`, `ecs_system`, `ecs_new_w_pair`). Use the function underneath (`ecs_field_w_size`, `ecs_component_init`, `ecs_query_init`, `ecs_system_init`) or a shim. `ecs_query_desc_t.terms` imports as a 32-element tuple; fill it through `withUnsafeMutableBytes`, in one internal helper. Log messages arrive already formatted through `ecs_os_api.log_`, so no `va_list` shim is needed.

Components and memory:

- Register a component with `size == 0 ? 0 : stride` from `MemoryLayout`, and pass the same number to `ecs_field_w_size`. Never the plain `size`: Swift pointers advance by stride, so a type with trailing padding like `{ Int64, Int8 }` would read the wrong rows.
- A zero-size Swift struct is a Flecs tag and has no column. It never appears as a field in an iterator.
- Component ids are per world. Registration is a map from `ObjectIdentifier(T.self)` to `ecs_entity_t`, kept in a heap box in the world's binding context so it is reachable from a bare `ecs_world_t*` and freed with the world. No global id cache. Resolve ids when a query is built, never per row.
- Types that are not plain data (`_isPOD` is false: anything holding a `String`, array or class) get `dtor`, `copy` and `move` hooks, generic C-convention thunks that find `T` through `ecs_type_info_t`. Flecs must never memcpy or forget one of these. Swift types have no universal default initializer, so mark the constructor `ECS_TYPE_HOOK_CTOR_ILLEGAL` unless the type offers one, and create values with `ecs_emplace_id` plus `initialize(to:)` rather than a default-construct then assign. `~Copyable` components set `ECS_TYPE_HOOK_COPY_ILLEGAL`.
- Component names sent to Flecs must be sanitized: `.` is Flecs' path separator, and `String(reflecting:)` returns names like `Game.Position<Game.Tag>`.
- Pointers into component storage die on any structural change. No public API returns one that can outlive a closure. `world.get` returns a copy; access in place is a scoped closure.
- Closures stored for systems, observers and hooks live in retained boxes released by Flecs' `callback_ctx_free` and friends. Never leave them to the user, and never leak them on `ecs_fini`. A Swift closure cannot be a `@convention(c)` callback, so every callback is a capture-free generic thunk that recovers the box from the context.

## Platform support

- Linux, macOS and Windows: Flecs needs little from the system beyond the C runtime and threads. Windows needs the Swift toolchain plus the MSVC build tools and Windows SDK, which Swift needs but does not install. Platform-specific linker and define settings live in `Package.swift` with `.when(platforms:)`.
- Web: the Swift SDK for Wasm, which targets `wasm32-unknown-wasip1`. Emscripten is not part of the plan. Flecs 4.2.0 compiles for this target once `FLECS_NO_HTTP` and `FLECS_NO_REST` are set under `__wasm__` in `CFlecs.h`, because the HTTP addon includes `netdb.h`, which WASI lacks. A Swift spike calling the C API directly (create a world, register a component, set, get, progress, destroy) ran correctly under Node's WASI in debug and release. The Scream API itself has not been built or run there yet.

Web rules:

- Scream builds for Wasm from the first commit, and CI keeps it that way. A change that breaks the Wasm build is not done, the same as any other platform.
- WASI has no threads and no sockets. Flecs' POSIX thread path aborts if `pthread_create` fails, so asking for worker threads on a target without them must fall back to running on the calling thread instead of reaching that abort. Multi-threaded systems then run serially, with no API difference. The Flecs Explorer, which needs REST, is unavailable on the web.
- `progress` runs one frame and returns, so a browser host can call it from `requestAnimationFrame`. Never make a blocking run loop the only way to drive a world, and do not let the frame-rate limiter sleep on the web.
- Scream has no window or graphics code, so unlike Swaylib it needs no browser platform layer. It depends on WASI only. JavaScriptKit and its PackageToJS plugin are what a browser application uses to host it, so they belong in a browser example with its own `Package.swift` under `Examples/`, never in Scream's dependencies.
- When `Roadmap.md` is created it gets a Web section tracking this work.

Platform checks in Swift source are allowed only inside `Scream`, never in examples, and should be rare.

## API design rules

- Flecs is not bound to one thread the way raylib is, so nothing here is `@MainActor`. A `World` is a non-`Sendable`, `~Copyable` struct that owns its `ecs_world_t` and calls `ecs_fini` in `deinit`. It can be sent to another thread as a whole, but not shared. The package builds in the Swift 6 language mode with complete concurrency checking.
- `Entity` is a plain `Hashable`, `Sendable`, `BitwiseCopyable` wrapper layout-identical to `ecs_entity_t`, so entities are safe to store in components and cross threads. It holds no world pointer and cannot dangle. Operations go through a world or stage (`world.set(entity, Position(...))`).
- During `progress`, Flecs is in deferred mode and writes must go through the stage for the current thread. System and observer closures receive their own non-owning stage value and use that. The noncopyable `World` cannot be captured by an escaping closure, so the compiler enforces this; do not add an escape hatch.
- Systems run on the thread calling `progress` unless marked multi-threaded. A multi-threaded system takes a `@Sendable` closure and its components must be `Sendable`, so the unsafe case does not compile.
- Queries are typed with parameter packs and access wrappers: `world.query(InOut<Position>.self, In<Velocity>.self)`. Access is part of the type because Flecs uses it for scheduling and change detection. Keep Flecs' `In`, `InOut` and `Out` naming. Fall back to `QueryBuilder` for what types cannot express: variables, traversal, `Or`, cascade, or more terms than a pack can reasonably hold. Flecs' limit is 32 terms.
- As of Swift 6.4.2, a closure of `(repeat inout each T)` can be declared but not called through a pack, and `MutableSpan` cannot be a pack element. So per-entity closures receive small `Copyable` accessors for each term with `@dynamicMemberLookup` (`position.x += velocity.x`), and per-table iteration receives a `Column<T>` wrapper that is bounds checked in debug. Recheck on each toolchain bump.
- Hot-path generics are `@inlinable` with `@usableFromInline` internals so they specialize across modules. Any change to them runs the benchmarks.
- Long-lived Flecs objects with ownership (`World`, cached `Query`) are noncopyable structs that release themselves in `deinit`. Never leave cleanup to the user. Use a class only when a resource really needs shared ownership.
- Failures a caller can trigger with data (a bad query expression, a failed module import) `throw(ScreamError)`. Misuse that Flecs treats as a bug (a stale entity, a missing component on a required access) stays a trap, with the Flecs message intact. Do not paper over assertions by making everything optional.
- Paired `begin`/`end` calls are scoped closures: `world.deferred { stage in }`, `world.readonly { }`. A mismatched `end` must be impossible to write. Flecs 4.2 has no `ecs_defer_begin`: deferring means writing through a stage and merging it, so `deferred` hands out stage 0 and merges it when the closure returns.
- A tag registers with size 0 and alignment 0; Flecs asserts on size 0 with a nonzero alignment.
- C enums and flag sets are generated Swift enums and `OptionSet`s. Raw `ecs_flags32_t` and `ecs_id_t` bit-twiddling never appears in the public API. A pair is a `Pair` value, not an `ecs_pair` integer.
- Use Swift naming and keep Flecs' terminology (world, entity, component, tag, pair, relationship, query, system, phase, pipeline, observer, prefab, module) so its docs still help. Overloads that differ only in a numeric type make integer literals ambiguous, so give them distinct names.
- Strings go in as Swift `String`; no `UnsafePointer<CChar>` in the public API. Same for arrays and buffers.
- Do not build a game engine on top. No app framework, scene format or renderer integration in `Scream`.
- Swift Testing's `#expect` cannot expand member accesses on noncopyable values. In tests, read `world.count` and friends into locals first.

## Building and testing

These commands apply once the package exists.

- `swift build` builds Flecs and everything else. Requires the Swift version in `.swift-version` (swiftly installs it).
- `swift build --swift-sdk swift-6.4.2-RELEASE_wasm --product Scream` builds for Wasm; the SDK version must match `.swift-version` (`swift sdk list` shows what is installed). Name the product, because `scream-generate` uses `Foundation.Process`, which WASI does not have, so a plain `swift build` fails there. The output runs under any WASI runtime, including Node's `node:wasi`.
- `swift test` runs the Swift Testing suites. `swift test --sanitize=address --disable-xctest` and `--sanitize=thread --disable-xctest` on Linux are required for anything touching hooks, callbacks, boxes or threads, and CI runs both. `--disable-xctest` matters: the XCTest runner leaks a few objects of its own and the leak checker fails the run on them. That is Swift's sanitizer flag and is unrelated to `FLECS_SANITIZE`.
- `swift run scream-generate` regenerates `Sources/Scream/Generated/` and the API Coverage page; `--check` only verifies. Run it after touching `Tools/Generate/` or `wrapped.txt`.
- CI builds and tests on Linux, Windows and macOS, and builds and runs the examples on Wasm. A change that only builds on the platform you happen to be on is not done. When a CI job fails on a platform you cannot run, read the log and fix it; do not disable the job.
- When adding Flecs API: write the wrapper with a doc comment, add a line per C function to `Tools/Generate/wrapped.txt`, regenerate, cover it with a test or an example, and list any new public type under a topic in `Scream.docc/Scream.md`.

## Searching the Codebase

Use fast, modern tools instead of the slow defaults:

- [`rg`](https://github.com/BurntSushi/ripgrep) (ripgrep) for text search, not `grep`. It respects `.gitignore` for you. **NOTE**: Prefer to use [`ast-grep`](https://ast-grep.github.io) when applicable as it uses the structure of the code instead.
- [`fd`](https://github.com/sharkdp/fd) for finding files by name, not `find`.
- [`ast-grep`](https://ast-grep.github.io) for structural searches and rewrites, like finding every call to a function or every type that conforms to a protocol. It supports both Swift and C. Call it as `ast-grep`. The `sg` alias is deprecated, so don't use it.
- `jq` for reading and querying JSON, including the clang AST dump of `flecs.h`.

`flecs.h` is about 38,000 lines and `flecs.c` about 125,000. Search them; do not read them whole. Most of `flecs.h` past the C API is the C++ API, which is useful as a reference for how Flecs expects a binding to behave.

If your harness has dedicated search or file tools that already wrap these, those are fine too.

## Code Quality

Always lint and format:

- `swift format` (ships with the toolchain) formats and lints. Config lives in `.swift-format` at the root, the same as Swaylib's. `swift format --in-place --recursive Sources/Scream Tools Tests Examples Benchmarks Package.swift` fixes, `swift format lint --strict --recursive` over the same paths reports. CI runs the lint. The generator's output must pass it too.
- `.editorconfig`: UTF-8, LF, 4 spaces, 120 columns for Swift; 2 spaces for Markdown, TOML, YAML and JSON.
- Do not format or lint the Flecs submodule.

Use modern code practices:

- The latest stable Swift 6 release, Swift 6 language mode, complete strict concurrency. The toolchain is pinned in `.swift-version` (read by swiftly); `Package.swift` asks for tools version 6.2 so that users on 6.2 and newer can depend on the package.
- Swift Testing (`import Testing`, `@Test`, `#expect`), not XCTest.
- Typed throws, noncopyable types, parameter packs, `Span` and package traits are all fair game. Use them where they make the API better, not to show off.
- Use Foundation sparingly. It is fine for tests and the generator, but `Scream` itself does not import it, which keeps binaries small on Linux and Windows.
- No dependency gets added without a reason. Use the standard library and Flecs first. Do not add Swift macros: `swift-syntax` is a heavy dependency for every user, and generics cover component registration and queries. The only package dependency is the Swift-DocC plugin.

## Docs (IMPORTANT!!!)

Always update the docs if necessary when changing or adding code. If the docs already contain outdated information, expand your scope to cover that info too.

The docs are DocC only. Every public symbol gets a `///` doc comment, and longer material is written as articles in `Sources/Scream/Scream.docc/`. Build and check them with the [Swift-DocC plugin](https://github.com/swiftlang/swift-docc-plugin) (`swift package generate-documentation --target Scream --warnings-as-errors`), which CI runs, so broken symbol links fail the build. Articles: `GettingStarted.md`, `Threading.md`, `Platforms.md`, `APICoverage.md` (generated, never edited by hand), `Architecture.md`, `Development.md`, `Roadmap.md`. Topic groups in `Scream.md` (the catalog's landing page) must list every public type, so nothing ends up in an unsorted "Other" section.

When a roadmap item is finished, check it off (`- [x]`) where it is. DO NOT move it into an earlier section like "Done: the MVP". The roadmap shows how each goal is progressing, so finished items stay with the section they belong to.

## Diagrams as Mermaid, not ASCII art

Never draw a flow, pipeline or architecture picture out of characters in a code block. Make a Mermaid diagram instead. DocC cannot render Mermaid itself, so keep the `.mmd` source in the catalog's `Resources/`, render it to SVG with [mermaid-cli](https://github.com/mermaid-js/mermaid-cli) (a light and a `~dark` variant, which DocC picks between), and commit both the source and the SVGs. Edit the source and rerender; never hand-edit the SVG.

## Outdated packages

PLEASE, PLEASE do not use a package that is old or deprecated. EVEN IF IT IS "INDUSTRY STANDARD" THAT DOES NOT MEAN IT IS GOOD!!! USE THE BEST PACKAGE AND LATEST VERSION LIKE A NORMAL PERSON WOULD!

Before adding or bumping a Swift package, check its latest release on GitHub or the [Swift Package Index](https://swiftpackageindex.com). Before bumping Flecs, read its release notes for breaking changes and rerun the layout test. Toolchain versions come from [swift.org](https://www.swift.org/install/).

## Keep things human

Do no use em dashes or other special symbols not normally found in writing. Do not word things in a weird way. Keep it looking human. If you need to use, for example, an arrow icon, use an SVG instead.

Replacing an em dash with a hyphen is NOT a fix. A spaced hyphen doing an em dash's job ("the limit - 4 bytes", "fast - but wrong") is the same tic with a different character. Reword the sentence instead: use a comma, a colon, parentheses, or the actual word ("minus", "to", "through"). Plain hyphens in compound words and numeric ranges like 0-1 are fine.

## Use American spelling

It's fine to be British in the chat if the person is actually in a region where its spelled like that. But if not just use American spelling. The thing itself MUST use American spelling.
