# Roadmap

Where Scream is and where it is going. Finished items stay in their section, checked off.

## MVP

- [x] Flecs built from source by SwiftPM on Linux, Windows, macOS and Wasm.
- [x] Generator for enums and builtin entities from `flecs.h`, and the API coverage page.
- [ ] World, entities, components, tags, pairs, hierarchies and prefabs.
- [ ] Lifecycle hooks for components that are not plain data.
- [ ] Typed queries and systems, pipelines and phases, observers.
- [ ] Multi-threaded systems.
- [ ] DocC documentation with a getting started guide.
- [ ] Examples, including ones that draw a Flecs world with Swaylib.
- [ ] CI results on Windows and macOS confirmed green.

## Flecs features

- [ ] Query builder for what the typed API cannot say: variables, traversal, `Or`, cascade.
- [ ] Modules.
- [ ] Singletons.
- [ ] Noncopyable components.
- [ ] Timers and rate filters.
- [ ] Reflection (the meta addon) for Swift types, so the Explorer can show component values.
- [ ] Flecs script.
- [ ] JSON serialization.
- [ ] Stats and metrics.

## Web

- [x] Flecs compiles for WASI with the HTTP and REST addons off.
- [x] A Swift program drives a world under Node's WASI.
- [ ] The examples run on Wasm on CI.
- [ ] Worker threads fall back to the calling thread where there are none.
- [ ] A browser example with JavaScriptKit, driven from `requestAnimationFrame`.
