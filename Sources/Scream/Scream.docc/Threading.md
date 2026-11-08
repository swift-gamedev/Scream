# Threading

What may run where, and how Swift's concurrency checking enforces it.

## Overview

Flecs is not tied to one thread the way a windowing library is, but a world is not safe to share
either. Scream expresses the rules in types rather than documentation where it can.

## One world, one thread at a time

``World`` is a noncopyable struct that is not `Sendable`. It can be moved to another thread, but
two threads cannot hold it at once, and an escaping closure cannot capture it. Everything a system
or observer needs to write goes through the ``Stage`` its ``Iteration`` provides.

``Entity``, ``Id`` and ``Pair`` are plain ids: `Sendable` and `BitwiseCopyable`. They hold no
pointer to a world, so they can be stored in components and sent anywhere.

## Frames and stages

``World/progress(deltaTime:)`` puts the world in readonly mode, runs every system in phase order,
then merges the stages. A ``Stage`` is a per-thread queue of structural changes: adding,
removing, deleting, and setting a component an entity does not have yet are deferred until the
merge, while reads see the world as it is. That is why a system can delete the entity it is
looking at without breaking the iteration. Setting a component the entity already has is not
structural: Flecs writes the value at once and defers only the change notification. In a
multi-threaded system, change the components the closure declared through their ``Mut``
accessors, which is what the terms are for, and keep the stage for structural changes. Outside a
frame, ``World/deferred(_:)`` gives the same behavior for a block of code.

## Multi-threaded systems

``World/setThreads(_:)`` creates worker threads, and a system made with
`World.parallelSystem`
runs on all of them, each over its own slice of the matched entities. Its closure must be
`@Sendable` and its components `Sendable`, so a closure that captures something unsafe does not
compile. Ordinary systems always run on the thread that called `progress`, so they may capture
anything.

Register components before the first multi-threaded frame. Registration changes the world, which
is not allowed while the world is in multi-threaded readonly mode.

## The web

WASI has no threads. ``World/setThreads(_:)`` does nothing there and multi-threaded systems run on
the calling thread; the API and the results are the same.

## Creating worlds

Creating or destroying a world is serialized by Scream, because Flecs sets up its OS API and
counts worlds in global state. Two threads can each own a world and run them at the same time.

## Logging

``Log/setHandler(_:)`` installs one handler for the process. Flecs calls it from whichever
thread logs, including worker threads, so the handler is `@Sendable`. Set it before creating a
world.
