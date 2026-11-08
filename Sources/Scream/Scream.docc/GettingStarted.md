# Getting Started

A world, some components, a system and a frame loop.

## Overview

Scream wraps Flecs, so its [quickstart](https://www.flecs.dev/flecs/md_docs_2Quickstart.html)
explains the ideas: entities are ids, components are the data attached to them, systems are
functions that run over every entity with a given set of components. This article shows the same
things in Swift.

## Add the package

```swift
dependencies: [
    .package(url: "https://github.com/swift-gamedev/Scream.git", branch: "main"),
],
targets: [
    .executableTarget(name: "Game", dependencies: ["Scream"]),
],
```

Flecs is compiled into your program; there is nothing to install. See <doc:Platforms> for what
each system needs.

## A world and some entities

```swift
import Scream

struct Position: Component {
    var x: Double
    var y: Double
}

struct Velocity: Component {
    var x: Double
    var y: Double
}

struct Player: Component {}  // No data: a tag.

let world = World()

let player = world.entity("Player")
world.set(player, Position(x: 0, y: 0))
world.set(player, Velocity(x: 1, y: 0))
world.add(player, Player.self)
```

Any type can be a component by conforming to ``Component``; there is nothing to implement. The
world registers it the first time it sees it. ``WorldAccess/set(_:_:)`` adds a component or
replaces its value, ``WorldAccess/get(_:_:)`` returns a copy, ``WorldAccess/modify(_:_:_:)``
changes it in place, and `has` and `remove` do what they say. An ``Entity`` is only an id, so it goes everywhere: into components, across threads, into
dictionaries.

## Systems and frames

```swift
world.system(InOut<Position>.self, In<Velocity>.self, name: "Move") { position, velocity in
    position.x += velocity.x
    position.y += velocity.y
}

while world.progress() {
    // One frame has run.
}
```

A system is a query plus a closure that runs for every matched entity, each frame, in a phase.
``In`` reads a component and hands the closure a ``Ref``; ``InOut`` and ``Out`` hand it a
``Mut``, whose properties can be assigned. The closure can also take the entity, or the
``Iteration`` and the entity:

```swift
world.system(In<Position>.self, name: "Fall") { iteration, entity, position in
    if position.y < -100 {
        iteration.stage.delete(entity)
    }
}
```

Structural changes inside a frame go through ``Iteration/stage``: they are queued and applied
when the systems have run, so the tables a system iterates do not change under it. The
``Iteration`` also has ``Iteration/deltaTime``.

``World/progress(deltaTime:)`` runs one frame and returns `false` after ``WorldAccess/quit()``.
Pass the frame time or let Flecs measure it; ``World/targetFPS`` caps the rate.

## Queries outside systems

```swift
let players = world.query(In<Position>.self, filter: [.with(Player.self)])
players.each { entity, position in
    print(world.name(of: entity) ?? "?", position.x, position.y)
}
```

A ``Query`` is the same matching without the schedule. Filters narrow it to entities that have,
or do not have, a tag, component or pair. Create a query once and keep it; Flecs keeps it up to
date.

## Relationships

```swift
let parent = world.entity("Ship")
let turret = world.entity("Turret", parent: parent)
world.children(of: parent)           // [turret]
world.has(turret, .childOf(parent))  // true

let likes = world.entity("Likes")
let apples = world.entity("Apples")
world.add(player, Pair(likes, apples))
```

A ``Pair`` is a relationship between two entities. ``Pair/childOf(_:)`` builds hierarchies,
``Pair/isA(_:)`` makes an entity inherit from a prefab (``WorldAccess/prefab(_:)``), and any two
entities make a relationship of your own. A pair whose first entity is a component carries that
component's value, once per target: ``WorldAccess/set(_:_:target:)``.

## Observers

```swift
world.observer(In<Position>.self, events: [.onSet]) { _, entity, position in
    print("\(entity) moved to \(position.x), \(position.y)")
}
```

An observer runs when something happens to a matching entity: ``Entity/onAdd``, ``Entity/onSet``
or ``Entity/onRemove``.

## What next

<doc:Threading> explains what runs where. The <doc:APICoverage> page maps Flecs' functions to
Scream's symbols, for when you know the C API and want the Swift name.
