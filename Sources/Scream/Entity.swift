import CFlecs

/// An entity: a 64-bit id that components, tags and relationships attach to.
///
/// An `Entity` is only the id. It does not know which ``World`` it belongs to, so it is safe to
/// store inside components and to send between threads, and every operation on it goes through a
/// world: `world.set(entity, Position(x: 1, y: 2))`. Flecs' builtin entities, such as
/// ``childOf`` and ``onUpdate``, are static members.
public struct Entity: Hashable, Sendable, BitwiseCopyable {
    /// The id as Flecs stores it: the entity number in the low 32 bits and its generation above.
    public let rawValue: ecs_entity_t

    /// Wraps a raw Flecs entity id.
    public init(rawValue: ecs_entity_t) {
        self.rawValue = rawValue
    }

    /// The id 0, which Flecs uses for "no entity".
    public static var null: Entity { Entity(rawValue: 0) }

    /// Whether this is ``null``.
    public var isNull: Bool {
        rawValue == 0
    }
}

extension Entity: CustomStringConvertible {
    /// `Entity(<raw id>)`. Names live in a world, so this cannot show one.
    public var description: String {
        "Entity(\(rawValue))"
    }
}
