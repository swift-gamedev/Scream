import CFlecs
import CFlecsShims

/// A Flecs world: the store that holds every entity, component and system.
///
/// A world owns its Flecs state and destroys it when it goes out of scope. It can be moved to
/// another thread but not shared between threads; systems that run in parallel do so inside
/// ``progress(deltaTime:)``, on threads Flecs manages.
public struct World: ~Copyable {
    /// The `ecs_world_t` this world owns.
    @usableFromInline
    let raw: OpaquePointer

    /// Creates an empty world with Flecs' builtin components, phases and addons.
    public init() {
        // Through the shim, which serializes world creation: Flecs' OS API setup is not safe to
        // run from two threads at once.
        guard let world = screamInitWorld() else {
            fatalError("Flecs could not create a world")
        }
        raw = world
    }

    deinit {
        _ = screamFiniWorld(raw)
    }

    /// Runs one frame: every system in the pipeline, in phase order.
    ///
    /// - Parameter deltaTime: The time since the last frame in seconds, or 0 to let Flecs measure it.
    /// - Returns: `false` once ``quit()`` has been called, so a loop can stop.
    @discardableResult
    public func progress(deltaTime: Float = 0) -> Bool {
        ecs_progress(raw, deltaTime)
    }

    /// Makes the next ``progress(deltaTime:)`` return `false`.
    public func quit() {
        ecs_quit(raw)
    }

    /// Whether ``quit()`` has been called.
    public var shouldQuit: Bool {
        ecs_should_quit(raw)
    }
}
