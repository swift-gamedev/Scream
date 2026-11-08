# ``Scream``

Idiomatic Swift bindings for Flecs, on Linux, Windows, macOS and the web.

## Overview

Scream wraps [Flecs](https://www.flecs.dev), the entity component system, in Swift that reads
like Swift. Flecs itself is compiled into your program by Swift Package Manager, so nothing needs
to be installed. The names follow Flecs' own, so its documentation still helps: `ecs_progress`
is ``World/progress(deltaTime:)``, `EcsChildOf` is ``Entity/childOf``.

The <doc:APICoverage> page lists every Flecs function and what wraps it.

## Topics

### World and entities

- ``World``
- ``Entity``

### Flecs' enums

- ``InOutKind``
- ``OperatorKind``
- ``QueryCacheKind``
- ``TypeKind``
- ``PrimitiveKind``
- ``MetaOperationKind``
- ``HTTPMethod``
- ``ScriptFocusSource``
- ``ScriptTaskStatus``
- ``ScriptFutureStatus``
- ``ScriptTaskLoop``

### Project

- ``flecsVersion``
- <doc:APICoverage>
- <doc:Architecture>
- <doc:Platforms>
- <doc:Development>
- <doc:Roadmap>
