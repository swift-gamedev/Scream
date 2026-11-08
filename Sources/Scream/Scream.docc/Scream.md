# ``Scream``

Idiomatic Swift bindings for Flecs, on Linux, Windows, macOS and the web.

## Overview

Scream wraps [Flecs](https://www.flecs.dev), the entity component system, in Swift that reads
like Swift. Flecs itself is compiled into your program by Swift Package Manager, so nothing needs
to be installed. The names follow Flecs' own, so its documentation still helps: `ecs_progress`
is ``World/progress(deltaTime:)``, `EcsChildOf` is ``Entity/childOf``.

```swift
import Scream

struct Position: Component { var x, y: Double }

let world = World()
let player = world.entity("Player")
world.set(player, Position(x: 0, y: 0))
world.modify(player, Position.self) { $0.x += 1 }
```

Components are plain Swift types that conform to ``Component``; a world registers them on first
use, and ones that are not plain data get lifecycle hooks so Flecs copies and frees them through
Swift. An ``Entity`` is just an id, and every operation on it goes through a ``World`` or, inside
a frame, a ``Stage``; both share ``WorldAccess``. The world owns everything and destroys it when it
goes out of scope.

The <doc:APICoverage> page lists every Flecs function and what wraps it.

## Topics

### World and stages

- ``World``
- ``Stage``
- ``WorldAccess``

### Entities and components

- ``Entity``
- ``Component``
- ``Id``
- ``Pair``

### Logging

- ``Log``

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
