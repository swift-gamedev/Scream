import CFlecs
import CFlecsShims

/// Something that can be added to an entity: a component or tag ``Entity``, or a ``Pair``.
///
/// Flecs stores both in one 64-bit id, with a flag bit telling them apart. Most code never needs
/// an `Id` directly, because ``WorldAccess/add(_:_:)-(Entity,Entity)`` and friends take an
/// ``Entity``, a ``Pair`` or a component type; it appears when inspecting what an entity has.
public struct Id: Hashable, Sendable, BitwiseCopyable {
    /// The id as Flecs stores it.
    public let rawValue: ecs_id_t

    /// Wraps a raw Flecs id.
    public init(rawValue: ecs_id_t) {
        self.rawValue = rawValue
    }

    /// The id of a component or tag entity.
    public init(_ entity: Entity) {
        rawValue = entity.rawValue
    }

    /// The id of a pair.
    public init(_ pair: Pair) {
        rawValue = screamPair(pair.first.rawValue, pair.second.rawValue)
    }

    /// Whether this id is a pair rather than a single entity.
    public var isPair: Bool {
        screamIdIsPair(rawValue)
    }

    /// The entity, when this id is not a pair.
    public var entity: Entity? {
        isPair ? nil : Entity(rawValue: rawValue)
    }

    /// The pair, when this id is one.
    ///
    /// Flecs stores only the low 32 bits of each entity in a pair, so the entities returned here
    /// have no generation. ``WorldAccess/pair(of:)`` recovers it from the world.
    public var pair: Pair? {
        guard isPair else { return nil }
        return Pair(
            Entity(rawValue: (rawValue >> 32) & 0xFFFF_FFFF),
            Entity(rawValue: rawValue & 0xFFFF_FFFF))
    }
}

/// A relationship between two entities: `(first, second)`, such as `(ChildOf, parent)`.
///
/// The first entity is the relationship, the second its target. When the first entity is a
/// component, the pair carries that component's value: see
/// ``WorldAccess/set(_:_:target:)``.
public struct Pair: Hashable, Sendable, BitwiseCopyable {
    /// The relationship.
    public let first: Entity
    /// The target.
    public let second: Entity

    /// Pairs `first` with `second`.
    public init(_ first: Entity, _ second: Entity) {
        self.first = first
        self.second = second
    }

    /// `(ChildOf, parent)`: makes an entity a child of `parent`.
    public static func childOf(_ parent: Entity) -> Pair {
        Pair(.childOf, parent)
    }

    /// `(IsA, base)`: makes an entity inherit from `base`, usually a prefab.
    public static func isA(_ base: Entity) -> Pair {
        Pair(.isA, base)
    }

    /// This pair as an ``Id``.
    public var id: Id {
        Id(self)
    }
}
