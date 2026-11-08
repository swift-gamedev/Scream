import CFlecs
import CFlecsShims

/// A typed query: the entities that have every term's component, iterated with `each`.
///
/// ```swift
/// let movers = world.query(InOut<Position>.self, In<Velocity>.self)
/// movers.each { position, velocity in
///     position.x += velocity.x
/// }
/// ```
///
/// `Terms` is one of `Terms1` through `Terms8`, picked by the `World.query` overload for the
/// number of components. A query is cached by Flecs and kept up to date as entities change;
/// create it once and keep it. It is destroyed when it goes out of scope. Changing the world's
/// structure (adding or removing components, deleting entities) from inside `each` is an error;
/// do that through ``World/deferred(_:)`` around the call, or from a system, where writes are
/// deferred already.
public struct Query<Terms: QueryTerms>: ~Copyable {
    @usableFromInline
    let raw: UnsafeMutablePointer<ecs_query_t>
    @usableFromInline
    let world: OpaquePointer
    let context: WorldContext

    init(raw: UnsafeMutablePointer<ecs_query_t>, world: OpaquePointer, context: WorldContext) {
        self.raw = raw
        self.world = world
        self.context = context
    }

    deinit {
        // The world destroys its queries with it; only release one whose world is still here.
        if context.isAlive {
            ecs_query_fini(raw)
        }
    }

    /// Calls `body` for every matched entity with the accessors for each term.
    @inlinable
    public func each(_ body: Terms.Each) {
        var iterator = ecs_query_iter(world, raw)
        while ecs_query_next(&iterator) {
            withUnsafeMutablePointer(to: &iterator) { Terms.forEach(Iteration(raw: $0), body: body) }
        }
    }

    /// Calls `body` for every matched entity with the entity and the accessors for each term.
    @inlinable
    public func each(_ body: Terms.EachEntity) {
        var iterator = ecs_query_iter(world, raw)
        while ecs_query_next(&iterator) {
            withUnsafeMutablePointer(to: &iterator) { Terms.forEachEntity(Iteration(raw: $0), body: body) }
        }
    }

    /// Calls `body` for every matched entity with the iteration context, the entity and the
    /// accessors for each term.
    @inlinable
    public func each(_ body: Terms.EachIteration) {
        var iterator = ecs_query_iter(world, raw)
        while ecs_query_next(&iterator) {
            withUnsafeMutablePointer(to: &iterator) { Terms.forEachIteration(Iteration(raw: $0), body: body) }
        }
    }

    /// How many entities the query matches right now.
    public var count: Int {
        Int(ecs_query_count(raw).entities)
    }

    /// Whether the query matches anything right now.
    public var isEmpty: Bool {
        !ecs_query_is_true(raw)
    }

    /// The query in Flecs' query language, as Flecs prints it.
    public var description: String {
        guard let text = ecs_query_str(raw) else { return "" }
        defer { screamFree(text) }
        return String(cString: text)
    }
}

extension World {
    /// Creates the query behind the generated `query` overloads.
    func makeQuery<Terms: QueryTerms>(filter: [QueryFilter]) -> Query<Terms> {
        var desc = ecs_query_desc_t()
        fillTerms(&desc, world: flecsWorld, terms: Terms.terms(in: stage()), filter: filter)
        guard let raw = ecs_query_init(flecsWorld, &desc) else {
            fatalError("Flecs rejected the query; see its log for the reason")
        }
        return Query(raw: raw, world: flecsWorld, context: context)
    }
}
