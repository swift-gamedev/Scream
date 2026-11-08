import CFlecs

/// A thread's view of a ``World`` whose writes are queued until the stage is merged.
///
/// While ``World/progress(deltaTime:)`` runs, each thread has a stage and the queues are merged
/// when the systems are done. System and observer closures receive the stage for the thread they
/// run on and use it like a world; ``World/deferred(_:)`` hands one out for code outside a frame.
/// A stage does not own anything and is only valid during that call.
public struct Stage: WorldAccess {
    /// The `ecs_world_t` of the stage, for calling Flecs' C API directly.
    public let flecsWorld: OpaquePointer

    init(flecsWorld: OpaquePointer) {
        self.flecsWorld = flecsWorld
    }

    /// The time the current frame has as its step, in seconds.
    public var deltaTime: Float {
        ecs_get_world_info(flecsWorld).pointee.delta_time
    }
}
