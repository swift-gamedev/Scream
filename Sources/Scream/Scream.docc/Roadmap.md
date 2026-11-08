# Roadmap

Where Scream is and where it is going. Finished items stay in their section, checked off.

## MVP

- [x] Flecs built from source by SwiftPM on Linux, Windows, macOS and Wasm.
- [x] Generator for enums and builtin entities from `flecs.h`, and the API coverage page.
- [x] World, entities, components, tags, pairs, hierarchies and prefabs.
- [x] Lifecycle hooks for components that are not plain data.
- [x] Typed queries and systems, pipelines and phases, observers.
- [x] Multi-threaded systems.
- [x] DocC documentation with a getting started guide.
- [x] A benchmark of query iteration against the same loop on the C API.
- [x] Examples, including ones that draw a Flecs world with Swaylib.
- [ ] CI results on Windows and macOS confirmed green.

## Flecs features

- [ ] Query builder for what the typed API cannot say: variables, traversal, `Or`, cascade.
- [ ] Modules.
- [x] Singletons.
- [ ] Noncopyable components.
- [ ] Optional terms, so a closure can receive a component that may be missing.
- [ ] Per-table iteration with columns, for code that wants the raw arrays.
- [x] Intervals and rates for systems.
- [ ] Timers as entities, and custom tick sources.
- [ ] Reflection (the meta addon) for Swift types, so the Explorer can show component values.
- [ ] Flecs script.
- [ ] JSON serialization.
- [ ] Stats and metrics.

## Web

- [x] Flecs compiles for WASI with the HTTP and REST addons off.
- [x] A Swift program drives a world under Node's WASI.
- [x] The console examples run on Wasm on CI, under Node's WASI.
- [x] Worker threads fall back to the calling thread where there are none.
- [ ] A browser example with JavaScriptKit, driven from `requestAnimationFrame`.
