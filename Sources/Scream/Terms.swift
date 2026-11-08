import CFlecs

/// One typed term of a ``Query``: a component and how the query accesses it.
///
/// The three terms are ``In``, ``InOut`` and ``Out``. The access mode is part of the type
/// because Flecs uses it to order systems and detect changes, and because it decides whether the
/// closure receives a ``Ref`` or a ``Mut``.
public protocol QueryTerm {
    /// The component the term matches.
    associatedtype Value: Component
    /// What the closure receives for this term: a ``Ref`` or a ``Mut`` of ``Value``.
    associatedtype Access

    /// Flecs' access mode for the term.
    static var inOut: InOutKind { get }

    /// The accessor for one row of a field.
    static func access(_ field: Field<Self>, row: Int) -> Access
}

/// Reads `T`: the closure receives a ``Ref``.
public struct In<T: Component>: QueryTerm {
    /// The component read.
    public typealias Value = T
    /// Read access to one entity's `T`.
    public typealias Access = Ref<T>

    /// `In`.
    public static var inOut: InOutKind { .in }

    /// A ``Ref`` to the value at `row`.
    @inlinable
    public static func access(_ field: Field<Self>, row: Int) -> Ref<T> {
        Ref(pointer: UnsafePointer(field.pointer(row: row)))
    }
}

/// Reads and writes `T`: the closure receives a ``Mut``.
public struct InOut<T: Component>: QueryTerm {
    /// The component read and written.
    public typealias Value = T
    /// Read and write access to one entity's `T`.
    public typealias Access = Mut<T>

    /// `InOut`.
    public static var inOut: InOutKind { .inOut }

    /// A ``Mut`` to the value at `row`.
    @inlinable
    public static func access(_ field: Field<Self>, row: Int) -> Mut<T> {
        Mut(pointer: field.pointer(row: row))
    }
}

/// Writes `T` without reading it: the closure receives a ``Mut``. Flecs schedules a system that
/// only writes a component before systems that read it.
public struct Out<T: Component>: QueryTerm {
    /// The component written.
    public typealias Value = T
    /// Write access to one entity's `T`.
    public typealias Access = Mut<T>

    /// `Out`.
    public static var inOut: InOutKind { .out }

    /// A ``Mut`` to the value at `row`.
    @inlinable
    public static func access(_ field: Field<Self>, row: Int) -> Mut<T> {
        Mut(pointer: field.pointer(row: row))
    }
}

/// Read access to one entity's component during iteration.
///
/// Properties of the component read through it directly: `velocity.x`. ``value`` is the whole
/// component. A `Ref` is only valid inside the closure that received it.
@dynamicMemberLookup
public struct Ref<T> {
    @usableFromInline
    let pointer: UnsafePointer<T>

    @inlinable
    init(pointer: UnsafePointer<T>) {
        self.pointer = pointer
    }

    /// The component's value.
    @inlinable
    public var value: T {
        pointer.pointee
    }

    /// A property of the component.
    @inlinable
    public subscript<U>(dynamicMember keyPath: KeyPath<T, U>) -> U {
        pointer.pointee[keyPath: keyPath]
    }
}

/// Read and write access to one entity's component during iteration.
///
/// Properties of the component read and write through it directly: `position.x += 1`. ``value``
/// is the whole component. A `Mut` is only valid inside the closure that received it.
@dynamicMemberLookup
public struct Mut<T> {
    @usableFromInline
    let pointer: UnsafeMutablePointer<T>

    @inlinable
    init(pointer: UnsafeMutablePointer<T>) {
        self.pointer = pointer
    }

    /// The component's value.
    @inlinable
    public var value: T {
        get { pointer.pointee }
        nonmutating set { pointer.pointee = newValue }
    }

    /// A property of the component.
    @inlinable
    public subscript<U>(dynamicMember keyPath: WritableKeyPath<T, U>) -> U {
        get { pointer.pointee[keyPath: keyPath] }
        nonmutating set { pointer.pointee[keyPath: keyPath] = newValue }
    }
}

/// The terms of a query as one type: which components, with which access, and how to call a
/// closure for every row.
///
/// The conforming types are `Terms1` through `Terms8`, one per number of components, written by
/// the generator. `Query`, `World.system` and `World.observer` are generic over this protocol
/// instead of over a parameter pack because Swift does not specialize packs, which made a row
/// loop about 70 times slower.
public protocol QueryTerms {
    /// A closure over the accessors, one per term.
    associatedtype Each
    /// A closure over the entity and the accessors.
    associatedtype EachEntity
    /// A closure over the iteration, the entity and the accessors.
    associatedtype EachIteration

    /// The terms' ids and access modes in `stage`'s world.
    static func terms(in stage: Stage) -> [(id: Id, inOut: InOutKind)]

    /// Calls `body` for every row of `iteration`.
    static func forEach(_ iteration: Iteration, body: Each)

    /// Calls `body` for every row of `iteration` with its entity.
    static func forEachEntity(_ iteration: Iteration, body: EachEntity)

    /// Calls `body` for every row of `iteration` with the iteration and its entity.
    static func forEachIteration(_ iteration: Iteration, body: EachIteration)
}

/// Where a query term's values are for the current table: one column, or one shared value.
///
/// Created by the iteration code for each term and handed to ``QueryTerm/access(_:row:)``.
public struct Field<Term: QueryTerm> {
    @usableFromInline
    let iterator: UnsafeMutablePointer<ecs_iter_t>
    @usableFromInline
    let index: Int8
    /// The column's first value, or the single shared value; nil for a row field.
    @usableFromInline
    let base: UnsafeMutableRawPointer?
    /// A shared field (from a prefab or a singleton) has one value for every row.
    @usableFromInline
    let isShared: Bool

    /// The field for term `index` of the iteration's current result.
    @inlinable
    public init(iteration: Iteration, index: Int8) {
        iterator = iteration.raw
        self.index = index
        let size = MemoryLayout<Term.Value>.stride
        // Sparse components are row fields: no column, Flecs looks each row up.
        if iterator.pointee.row_fields & (1 << UInt32(index)) != 0 {
            base = nil
            isShared = false
        } else {
            base = ecs_field_w_size(iterator, size, index)
            isShared = !ecs_field_is_self(iterator, index)
        }
    }

    /// The value for `row`, as a pointer to `Term.Value`.
    @inlinable
    public func pointer(row: Int) -> UnsafeMutablePointer<Term.Value> {
        let raw: UnsafeMutableRawPointer
        if let base {
            raw = isShared ? base : base + row * MemoryLayout<Term.Value>.stride
        } else {
            guard
                let at = ecs_field_at_w_size(iterator, MemoryLayout<Term.Value>.stride, index, Int32(row))
            else {
                fatalError("Flecs has no value for field \(index) at row \(row)")
            }
            raw = at
        }
        return raw.assumingMemoryBound(to: Term.Value.self)
    }
}
