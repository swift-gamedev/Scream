import CFlecs
import CFlecsShims

/// The operations shared by a ``World`` and its ``Stage``s: creating entities and giving them
/// components, tags and relationships.
///
/// On a `World` every operation happens at once. On a `Stage`, which system and observer
/// closures receive, structural changes are queued and applied when the stage is merged, at the
/// end of the frame or of ``World/deferred(_:)``; reads, and writes to components an entity
/// already has, go straight to the world. ``Stage`` has the details.
public protocol WorldAccess: ~Copyable {
    /// The `ecs_world_t` (or stage) underneath, for calling Flecs' C API directly.
    var flecsWorld: OpaquePointer { get }
}

extension WorldAccess where Self: ~Copyable {
    /// The Swift-side state of the world this stage belongs to.
    var context: WorldContext {
        guard let pointer = ecs_get_binding_ctx(flecsWorld) else {
            fatalError("This ecs_world_t was not created by Scream")
        }
        return Unmanaged<WorldContext>.fromOpaque(pointer).takeUnretainedValue()
    }

    // MARK: Entities

    /// Creates an entity with nothing attached.
    public func entity() -> Entity {
        Entity(rawValue: ecs_new(flecsWorld))
    }

    /// Finds the entity called `name` in the current scope, or creates it.
    ///
    /// `name` may be a path with `.` separators, such as `Enemies.Boss`, whose parents are created
    /// too. With `parent`, the name is relative to that entity instead.
    public func entity(_ name: String, parent: Entity? = nil) -> Entity {
        name.withCString { name in
            var desc = ecs_entity_desc_t()
            desc.name = name
            desc.parent = parent?.rawValue ?? 0
            return Entity(rawValue: ecs_entity_init(flecsWorld, &desc))
        }
    }

    /// Creates a prefab, an entity that other entities inherit from through ``Pair/isA(_:)``.
    /// Prefabs are not matched by queries unless the query asks for them.
    public func prefab(_ name: String? = nil) -> Entity {
        let prefab = name.map { entity($0) } ?? entity()
        ecs_add_id(flecsWorld, prefab.rawValue, EcsPrefab)
        return prefab
    }

    /// The entity at `path` (`Enemies.Boss`, relative to the current scope), if there is one.
    public func lookup(_ path: String) -> Entity? {
        let entity = ecs_lookup(flecsWorld, path)
        return entity == 0 ? nil : Entity(rawValue: entity)
    }

    /// The name of `entity`, without its parents, or nil if it has none.
    public func name(of entity: Entity) -> String? {
        guard let name = ecs_get_name(flecsWorld, entity.rawValue) else { return nil }
        return String(cString: name)
    }

    /// The full path of `entity` from the root, with `.` between the names, or nil if it has no
    /// name.
    public func path(of entity: Entity) -> String? {
        guard ecs_get_name(flecsWorld, entity.rawValue) != nil,
            let path = ecs_get_path_w_sep(flecsWorld, 0, entity.rawValue, ".", nil)
        else { return nil }
        defer { screamFree(path) }
        return String(cString: path)
    }

    /// Names or renames `entity`.
    public func setName(_ entity: Entity, _ name: String) {
        _ = ecs_set_name(flecsWorld, entity.rawValue, name)
    }

    /// Whether `entity` exists and has not been deleted. A recycled id with an old generation is
    /// not alive.
    public func isAlive(_ entity: Entity) -> Bool {
        ecs_is_alive(flecsWorld, entity.rawValue)
    }

    /// Deletes `entity` and everything that depends on it, such as its children.
    public func delete(_ entity: Entity) {
        ecs_delete(flecsWorld, entity.rawValue)
    }

    /// Deletes every entity that has `id`.
    public func deleteAll(with id: Id) {
        ecs_delete_with(flecsWorld, id.rawValue)
    }

    /// Removes every component, tag and relationship from `entity`, keeping it alive.
    public func clear(_ entity: Entity) {
        ecs_clear(flecsWorld, entity.rawValue)
    }

    /// Enables or disables `entity`. Disabled entities are skipped by queries and systems.
    public func setEnabled(_ entity: Entity, _ enabled: Bool) {
        ecs_enable(flecsWorld, entity.rawValue, enabled)
    }

    /// Whether `entity` is enabled; see ``setEnabled(_:_:)``.
    public func isEnabled(_ entity: Entity) -> Bool {
        !ecs_has_id(flecsWorld, entity.rawValue, EcsDisabled)
    }

    /// Everything attached to `entity`, in storage order.
    public func type(of entity: Entity) -> [Id] {
        guard let type = ecs_get_type(flecsWorld, entity.rawValue) else { return [] }
        return (0..<Int(type.pointee.count)).map { Id(rawValue: type.pointee.array[$0]) }
    }

    // MARK: Components and tags

    /// The entity that represents component or tag `type` in this world, registering it if needed.
    public func component<T: Component>(_ type: T.Type) -> Entity {
        Entity(rawValue: componentId(type))
    }

    /// Adds `id` to `entity`: a tag, a pair, or a component with a zero-filled value.
    public func add(_ entity: Entity, _ id: Id) {
        ecs_add_id(flecsWorld, entity.rawValue, id.rawValue)
    }

    /// Adds the tag or component entity `tag` to `entity`.
    public func add(_ entity: Entity, _ tag: Entity) {
        ecs_add_id(flecsWorld, entity.rawValue, tag.rawValue)
    }

    /// Adds `pair` to `entity`, such as `.childOf(parent)`.
    public func add(_ entity: Entity, _ pair: Pair) {
        ecs_add_id(flecsWorld, entity.rawValue, pair.id.rawValue)
    }

    /// Adds tag `type` to `entity`. For a component with data, use ``set(_:_:)`` instead; this
    /// traps if `type` holds anything that is not plain data, since Flecs could not initialize it.
    public func add<T: Component>(_ entity: Entity, _ type: T.Type) {
        precondition(
            MemoryLayout<T>.size == 0 || _isPOD(type),
            "\(type) is not plain data; set a value with set(_:_:) instead of add")
        ecs_add_id(flecsWorld, entity.rawValue, componentId(type))
    }

    /// Removes `id` from `entity`, if present.
    public func remove(_ entity: Entity, _ id: Id) {
        ecs_remove_id(flecsWorld, entity.rawValue, id.rawValue)
    }

    /// Removes the tag or component entity `tag` from `entity`, if present.
    public func remove(_ entity: Entity, _ tag: Entity) {
        ecs_remove_id(flecsWorld, entity.rawValue, tag.rawValue)
    }

    /// Removes `pair` from `entity`, if present.
    public func remove(_ entity: Entity, _ pair: Pair) {
        ecs_remove_id(flecsWorld, entity.rawValue, pair.id.rawValue)
    }

    /// Removes component or tag `type` from `entity`, if present.
    public func remove<T: Component>(_ entity: Entity, _ type: T.Type) {
        ecs_remove_id(flecsWorld, entity.rawValue, componentId(type))
    }

    /// Whether `entity` has `id`, including through a prefab it inherits from.
    public func has(_ entity: Entity, _ id: Id) -> Bool {
        ecs_has_id(flecsWorld, entity.rawValue, id.rawValue)
    }

    /// Whether `entity` has the tag or component entity `tag`.
    public func has(_ entity: Entity, _ tag: Entity) -> Bool {
        ecs_has_id(flecsWorld, entity.rawValue, tag.rawValue)
    }

    /// Whether `entity` has `pair`. ``Entity/wildcard`` matches any entity on either side.
    public func has(_ entity: Entity, _ pair: Pair) -> Bool {
        ecs_has_id(flecsWorld, entity.rawValue, pair.id.rawValue)
    }

    /// Whether `entity` has component or tag `type`.
    public func has<T: Component>(_ entity: Entity, _ type: T.Type) -> Bool {
        ecs_has_id(flecsWorld, entity.rawValue, componentId(type))
    }

    /// Sets `entity`'s `T` to `value`, adding the component if it was missing.
    public func set<T: Component>(_ entity: Entity, _ value: T) {
        setValue(entity, id: componentId(T.self), value)
    }

    /// Sets the value of the pair `(T, target)` on `entity`: `T`'s data, once per target.
    public func set<T: Component>(_ entity: Entity, _ value: T, target: Entity) {
        setValue(entity, id: screamPair(componentId(T.self), target.rawValue), value)
    }

    /// A copy of `entity`'s `T`, or nil if it has none. The copy is a snapshot; use
    /// ``modify(_:_:_:)`` to change the stored value.
    public func get<T: Component>(_ entity: Entity, _ type: T.Type) -> T? {
        getValue(entity, id: componentId(type))
    }

    /// A copy of the value of the pair `(T, target)` on `entity`, or nil if it has none.
    public func get<T: Component>(_ entity: Entity, _ type: T.Type, target: Entity) -> T? {
        getValue(entity, id: screamPair(componentId(type), target.rawValue))
    }

    /// Changes `entity`'s `T` in place and tells Flecs it changed, so observers see it.
    ///
    /// - Returns: What `body` returned, or nil if `entity` has no `T`.
    @discardableResult
    public func modify<T: Component, R>(_ entity: Entity, _ type: T.Type, _ body: (inout T) throws -> R) rethrows
        -> R?
    {
        let id = componentId(type)
        guard ecs_has_id(flecsWorld, entity.rawValue, id),
            let pointer = ecs_ensure_id(flecsWorld, entity.rawValue, id, componentSize(type))
        else { return nil }
        defer { ecs_modified_id(flecsWorld, entity.rawValue, id) }
        return try body(&pointer.assumingMemoryBound(to: T.self).pointee)
    }

    /// How many entities have component or tag `type`.
    public func count<T: Component>(_ type: T.Type) -> Int {
        Int(ecs_count_id(flecsWorld, componentId(type)))
    }

    /// How many entities have `id`.
    public func count(_ id: Id) -> Int {
        Int(ecs_count_id(flecsWorld, id.rawValue))
    }

    // MARK: Singletons

    /// Sets the world's single `T`, stored on the component's own entity.
    public func setSingleton<T: Component>(_ value: T) {
        let id = componentId(T.self)
        setValue(Entity(rawValue: id), id: id, value)
    }

    /// A copy of the world's single `T`, or nil if none was set.
    public func singleton<T: Component>(_ type: T.Type) -> T? {
        let id = componentId(type)
        return getValue(Entity(rawValue: id), id: id)
    }

    // MARK: Relationships

    /// The `index`th target of `relationship` on `entity`, such as the parent for
    /// ``Entity/childOf``, or nil if there is none.
    public func target(of entity: Entity, _ relationship: Entity, index: Int = 0) -> Entity? {
        let target = ecs_get_target(flecsWorld, entity.rawValue, relationship.rawValue, Int32(index))
        return target == 0 ? nil : Entity(rawValue: target)
    }

    /// The parent of `entity` (the target of its ``Entity/childOf`` pair), or nil.
    public func parent(of entity: Entity) -> Entity? {
        let parent = ecs_get_parent(flecsWorld, entity.rawValue)
        return parent == 0 ? nil : Entity(rawValue: parent)
    }

    /// The direct children of `parent`.
    public func children(of parent: Entity) -> [Entity] {
        var iterator = ecs_children(flecsWorld, parent.rawValue)
        var children: [Entity] = []
        while ecs_children_next(&iterator) {
            for index in 0..<Int(iterator.count) {
                children.append(Entity(rawValue: iterator.entities[index]))
            }
        }
        return children
    }

    /// The two entities of a pair id, with their generations restored from the world.
    public func pair(of id: Id) -> Pair? {
        guard id.isPair else { return nil }
        return Pair(
            Entity(rawValue: screamPairFirst(flecsWorld, id.rawValue)),
            Entity(rawValue: screamPairSecond(flecsWorld, id.rawValue)))
    }

    // MARK: Quitting

    /// Makes the next ``World/progress(deltaTime:)`` return `false`, so the frame loop can stop.
    /// Works from a system, through its stage.
    public func quit() {
        ecs_quit(flecsWorld)
    }

    /// Whether ``quit()`` has been called.
    public var shouldQuit: Bool {
        ecs_should_quit(flecsWorld)
    }

    // MARK: Internals

    /// The size Flecs stores for `T`: the stride, so that rows line up with Swift pointers, or 0
    /// for a tag.
    @usableFromInline
    func componentSize<T>(_ type: T.Type) -> Int {
        MemoryLayout<T>.size == 0 ? 0 : MemoryLayout<T>.stride
    }

    @usableFromInline
    func setValue<T>(_ entity: Entity, id: ecs_id_t, _ value: T) {
        let size = componentSize(T.self)
        guard size > 0 else {
            ecs_add_id(flecsWorld, entity.rawValue, id)
            return
        }
        // Swift types have no default initializer Flecs could call, so emplace hands back
        // uninitialized memory for a new component (the existing value otherwise) and Swift
        // initializes it. Flecs runs onAdd observers before that, so they must not read values;
        // Flecs' own set does the same for a component without a constructor.
        var isNew = false
        guard let raw = ecs_emplace_id(flecsWorld, entity.rawValue, id, size, &isNew) else {
            fatalError("Flecs returned no storage for component \(T.self)")
        }
        let pointer = raw.assumingMemoryBound(to: T.self)
        if isNew {
            pointer.initialize(to: value)
        } else {
            pointer.pointee = value
        }
        ecs_modified_id(flecsWorld, entity.rawValue, id)
    }

    @usableFromInline
    func getValue<T>(_ entity: Entity, id: ecs_id_t) -> T? {
        precondition(MemoryLayout<T>.size > 0, "\(T.self) is a tag and has no value; use has(_:_:)")
        guard let raw = ecs_get_id(flecsWorld, entity.rawValue, id) else { return nil }
        return raw.assumingMemoryBound(to: T.self).pointee
    }
}
