import CFlecs

/// A Swift closure stored in a Flecs callback context, called by the C thunk below.
@usableFromInline
final class CallbackBox {
    let run: (UnsafeMutablePointer<ecs_iter_t>) -> Void

    init(_ run: @escaping (UnsafeMutablePointer<ecs_iter_t>) -> Void) {
        self.run = run
    }
}

let callbackThunk: ecs_iter_action_t = { iterator in
    guard let iterator, let context = iterator.pointee.callback_ctx else { return }
    Unmanaged<CallbackBox>.fromOpaque(context).takeUnretainedValue().run(iterator)
}

let releaseCallbackBox: ecs_ctx_free_t = { context in
    guard let context else { return }
    Unmanaged<CallbackBox>.fromOpaque(context).release()
}

extension World {
    // MARK: Systems

    /// Creates the system behind the generated `system` and `parallelSystem` overloads. `run`
    /// is called once per table with the iteration and loops over its rows.
    @usableFromInline
    func makeSystem<Terms: QueryTerms>(
        _ terms: Terms.Type, name: String?, phase: Entity, filter: [QueryFilter], parallel: Bool,
        run: @escaping (Iteration) -> Void
    ) -> Entity {
        var desc = ecs_system_desc_t()
        desc.entity = name.map { entity($0) }?.rawValue ?? 0
        desc.phase = phase.rawValue
        desc.multi_threaded = parallel
        desc.callback = callbackThunk
        desc.callback_ctx = Unmanaged.passRetained(CallbackBox { run(Iteration(raw: $0)) }).toOpaque()
        desc.callback_ctx_free = releaseCallbackBox
        fillTerms(&desc.query, world: flecsWorld, terms: Terms.terms(in: stage()), filter: filter)
        let system = ecs_system_init(flecsWorld, &desc)
        precondition(system != 0, "Flecs rejected the system; see its log for the reason")
        return Entity(rawValue: system)
    }

    /// Runs `system` once, outside the pipeline.
    public func run(_ system: Entity, deltaTime: Float = 0) {
        _ = ecs_run(flecsWorld, system.rawValue, deltaTime, nil)
    }

    /// Makes `system` run every `seconds` instead of every frame. 0 removes the interval.
    public func setInterval(_ system: Entity, seconds: Float) {
        _ = ecs_set_interval(flecsWorld, system.rawValue, seconds)
    }

    /// Makes `system` run every `frames`th frame. 1 removes the rate.
    public func setRate(_ system: Entity, frames: Int) {
        _ = ecs_set_rate(flecsWorld, system.rawValue, Int32(frames), 0)
    }

    // MARK: Phases

    /// Creates a pipeline phase that runs after `after`, for systems to be placed in.
    ///
    /// Flecs' own phases are ``Entity/onStart``, ``Entity/preFrame``, ``Entity/onLoad``,
    /// ``Entity/postLoad``, ``Entity/preUpdate``, ``Entity/onUpdate``, ``Entity/onValidate``,
    /// ``Entity/postUpdate``, ``Entity/preStore``, ``Entity/onStore`` and ``Entity/postFrame``,
    /// in that order.
    public func phase(_ name: String, after: Entity) -> Entity {
        let phase = entity(name)
        add(phase, Entity.phase)
        add(phase, Pair(.dependsOn, after))
        return phase
    }
}
