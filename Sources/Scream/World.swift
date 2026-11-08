import CFlecs
import CFlecsShims

/// A Flecs world: the store that holds every entity, component and system.
///
/// A world owns its Flecs state and destroys it when it goes out of scope. It can be moved to
/// another thread but not shared between threads; systems that run in parallel do so inside
/// ``progress(deltaTime:)``, on threads Flecs manages. Everything you do with entities is in
/// ``WorldAccess``, which a world's ``Stage``s share.
public struct World: ~Copyable, WorldAccess {
    /// The `ecs_world_t` this world owns, for calling Flecs' C API directly.
    public let flecsWorld: OpaquePointer

    /// Creates an empty world with Flecs' builtin components, phases and addons.
    public init() {
        // Through the shim, which serializes world creation: Flecs' OS API setup is not safe to
        // run from two threads at once.
        guard let world = screamInitWorld() else {
            fatalError("Flecs could not create a world")
        }
        flecsWorld = world
        ecs_set_binding_ctx(flecsWorld, Unmanaged.passRetained(WorldContext()).toOpaque(), releaseContext)
    }

    deinit {
        context.isAlive = false
        _ = screamFiniWorld(flecsWorld)
    }

    // MARK: Frames

    /// Runs one frame: every system in the pipeline, in phase order.
    ///
    /// - Parameter deltaTime: The time since the last frame in seconds, or 0 to let Flecs measure it.
    /// - Returns: `false` once ``quit()`` has been called, so a loop can stop.
    @discardableResult
    public func progress(deltaTime: Float = 0) -> Bool {
        ecs_progress(flecsWorld, deltaTime)
    }

    /// The time the last frame took, in seconds, as passed to or measured by
    /// ``progress(deltaTime:)``.
    public var deltaTime: Float {
        ecs_get_world_info(flecsWorld).pointee.delta_time
    }

    /// How many frames ``progress(deltaTime:)`` has run.
    public var frameCount: Int {
        Int(ecs_get_world_info(flecsWorld).pointee.frame_count_total)
    }

    /// Caps the frame rate: ``progress(deltaTime:)`` sleeps so frames take at least
    /// `1 / targetFPS` seconds. 0 removes the cap.
    public var targetFPS: Float {
        get { ecs_get_world_info(flecsWorld).pointee.target_fps }
        nonmutating set { ecs_set_target_fps(flecsWorld, newValue) }
    }

    // MARK: Threads and stages

    /// Sets how many threads run multi-threaded systems during ``progress(deltaTime:)``.
    ///
    /// Flecs creates `count - 1` worker threads and uses the calling thread as well. On Wasm,
    /// which has no threads, this does nothing and every system runs on the calling thread.
    public func setThreads(_ count: Int) {
        #if arch(wasm32)
        _ = count
        #else
        ecs_set_threads(flecsWorld, Int32(count))
        #endif
    }

    /// The stage for thread `index`, for code that runs during a frame outside a system.
    public func stage(_ index: Int = 0) -> Stage {
        guard let stage = ecs_get_stage(flecsWorld, Int32(index)) else {
            fatalError("Flecs has no stage \(index) for this world; see setThreads(_:)")
        }
        return Stage(flecsWorld: stage)
    }

    /// Runs `body` with a stage whose structural changes are queued and applied when `body`
    /// returns.
    ///
    /// Use it to add, remove, delete or create while iterating, where changing a table under the
    /// iterator would be an error. Reads through the stage see the world as it is, and so do
    /// writes to components an entity already has; see ``Stage``.
    public func deferred<R>(_ body: (Stage) throws -> R) rethrows -> R {
        guard let stage = ecs_get_stage(flecsWorld, 0) else {
            fatalError("Flecs has no stage 0 for this world")
        }
        defer { ecs_merge(stage) }
        return try body(Stage(flecsWorld: stage))
    }

    /// Runs `body` with the world locked: writes must go through a ``stage(_:)`` and are merged
    /// when the block ends. This is what ``progress(deltaTime:)`` does around its systems.
    public func readonly<R>(_ body: () throws -> R) rethrows -> R {
        _ = ecs_readonly_begin(flecsWorld, false)
        defer { ecs_readonly_end(flecsWorld) }
        return try body()
    }
}

private let releaseContext: @convention(c) (UnsafeMutableRawPointer?) -> Void = { context in
    guard let context else { return }
    Unmanaged<WorldContext>.fromOpaque(context).release()
}
