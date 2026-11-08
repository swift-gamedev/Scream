import CFlecs

/// The context of one batch of matched entities, inside a system, observer or query closure.
///
/// Flecs hands results over one table at a time; an `Iteration` describes the current one. It is
/// only valid inside the closure that received it. ``stage`` is where writes go: during a frame
/// they are queued and merged when the systems have run.
public struct Iteration {
    @usableFromInline
    let raw: UnsafeMutablePointer<ecs_iter_t>

    @inlinable
    init(raw: UnsafeMutablePointer<ecs_iter_t>) {
        self.raw = raw
    }

    /// The stage to write through. Inside ``World/progress(deltaTime:)`` this is the thread's
    /// stage; when iterating a query by hand it is the world itself.
    public var stage: Stage {
        // Inside progress, Flecs 4.2 keeps the real world in `world` and the thread's stage in
        // `stage`; a query iterated by hand has only the world.
        guard let stage = raw.pointee.stage ?? raw.pointee.world else {
            fatalError("Flecs iterator has no world")
        }
        return Stage(flecsWorld: stage)
    }

    /// The frame's time step in seconds.
    public var deltaTime: Float {
        raw.pointee.delta_time
    }

    /// The time since this system last ran, in seconds; the same as ``deltaTime`` unless the
    /// system has an interval.
    public var systemDeltaTime: Float {
        raw.pointee.delta_system_time
    }

    /// How many entities are in this batch.
    public var count: Int {
        Int(raw.pointee.count)
    }

    /// The system running, or ``Entity/null`` outside one.
    public var system: Entity {
        Entity(rawValue: raw.pointee.system)
    }

    /// In an observer, the event that fired: ``Entity/onAdd``, ``Entity/onSet`` or
    /// ``Entity/onRemove``.
    public var event: Entity {
        Entity(rawValue: raw.pointee.event)
    }

    /// The entity at `row` of this batch.
    @inlinable
    public func entity(at row: Int) -> Entity {
        Entity(rawValue: raw.pointee.entities[row])
    }
}
