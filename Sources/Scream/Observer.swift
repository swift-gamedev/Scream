import CFlecs

extension World {
    /// Creates the observer behind the generated `observer` overloads. `run` is called once per
    /// batch of changed entities with the iteration and loops over its rows.
    @usableFromInline
    func makeObserver<Terms: QueryTerms>(
        _ terms: Terms.Type, events: [Entity], name: String?, filter: [QueryFilter], yieldExisting: Bool,
        run: @escaping (Iteration) -> Void
    ) -> Entity {
        precondition(!events.isEmpty, "An observer needs at least one event")
        precondition(events.count <= Int(FLECS_EVENT_DESC_MAX), "Flecs allows at most \(FLECS_EVENT_DESC_MAX) events")
        var desc = ecs_observer_desc_t()
        desc.entity = name.map { entity($0) }?.rawValue ?? 0
        desc.yield_existing = yieldExisting
        desc.callback = callbackThunk
        desc.callback_ctx = Unmanaged.passRetained(CallbackBox { run(Iteration(raw: $0)) }).toOpaque()
        desc.callback_ctx_free = releaseCallbackBox
        withUnsafeMutablePointer(to: &desc.events) { tuple in
            tuple.withMemoryRebound(to: ecs_entity_t.self, capacity: Int(FLECS_EVENT_DESC_MAX)) { slots in
                for (index, event) in events.enumerated() {
                    slots[index] = event.rawValue
                }
            }
        }
        fillTerms(&desc.query, world: flecsWorld, terms: Terms.terms(in: stage()), filter: filter)
        let observer = ecs_observer_init(flecsWorld, &desc)
        precondition(observer != 0, "Flecs rejected the observer; see its log for the reason")
        return Entity(rawValue: observer)
    }
}
