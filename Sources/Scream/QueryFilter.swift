import CFlecs
import CFlecsShims

/// A query term that narrows the match without delivering data: an entity must have, or must
/// not have, a tag, component or pair.
///
/// ```swift
/// world.query(InOut<Position>.self, filter: [.with(Player.self), .without(Frozen.self)])
/// ```
public struct QueryFilter {
    /// Resolves the id against the world the query is built for, since component ids differ
    /// per world.
    let resolve: (Stage) -> ecs_id_t
    let isNegated: Bool

    /// Matches entities that have component or tag `type`.
    public static func with<T: Component>(_ type: T.Type) -> QueryFilter {
        QueryFilter(resolve: { $0.componentId(type) }, isNegated: false)
    }

    /// Matches entities that have the tag or component `entity`.
    public static func with(_ entity: Entity) -> QueryFilter {
        QueryFilter(resolve: { _ in entity.rawValue }, isNegated: false)
    }

    /// Matches entities that have `pair`, such as `.childOf(parent)`. ``Entity/wildcard`` on
    /// either side matches any entity there.
    public static func with(_ pair: Pair) -> QueryFilter {
        QueryFilter(resolve: { _ in pair.id.rawValue }, isNegated: false)
    }

    /// Matches entities that have `id`.
    public static func with(_ id: Id) -> QueryFilter {
        QueryFilter(resolve: { _ in id.rawValue }, isNegated: false)
    }

    /// Matches entities that do not have component or tag `type`.
    public static func without<T: Component>(_ type: T.Type) -> QueryFilter {
        QueryFilter(resolve: { $0.componentId(type) }, isNegated: true)
    }

    /// Matches entities that do not have the tag or component `entity`.
    public static func without(_ entity: Entity) -> QueryFilter {
        QueryFilter(resolve: { _ in entity.rawValue }, isNegated: true)
    }

    /// Matches entities that do not have `pair`.
    public static func without(_ pair: Pair) -> QueryFilter {
        QueryFilter(resolve: { _ in pair.id.rawValue }, isNegated: true)
    }

    /// Matches entities that do not have `id`.
    public static func without(_ id: Id) -> QueryFilter {
        QueryFilter(resolve: { _ in id.rawValue }, isNegated: true)
    }
}

/// Writes the typed terms and filters of a query into a Flecs query descriptor.
func fillTerms(
    _ desc: inout ecs_query_desc_t, world: OpaquePointer, terms: [(id: Id, inOut: InOutKind)], filter: [QueryFilter]
) {
    let stage = Stage(flecsWorld: world)
    var ids: [(id: ecs_id_t, inOut: InOutKind, negated: Bool)] = terms.map { ($0.id.rawValue, $0.inOut, false) }
    for filter in filter {
        ids.append((filter.resolve(stage), .inOutNone, filter.isNegated))
    }
    precondition(ids.count <= Int(FLECS_TERM_COUNT_MAX), "Flecs allows at most \(FLECS_TERM_COUNT_MAX) terms per query")

    withUnsafeMutablePointer(to: &desc.terms) { tuple in
        tuple.withMemoryRebound(to: ecs_term_t.self, capacity: Int(FLECS_TERM_COUNT_MAX)) { terms in
            for (index, entry) in ids.enumerated() {
                terms[index].id = entry.id
                terms[index].inout = Int16(entry.inOut.rawValue)
                terms[index].oper = Int16(entry.negated ? OperatorKind.not.rawValue : OperatorKind.and.rawValue)
            }
        }
    }
}
