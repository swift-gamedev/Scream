import CFlecs
import CFlecsShims

/// A type that can be attached to entities.
///
/// Any Swift type can be a component by conforming; there is nothing to implement. A type with no
/// stored properties is a tag. A world registers a component the first time it sees the type,
/// under the type's qualified name, so `Game.Position` becomes the Flecs entity `Game.Position`.
///
/// Plain data types (numbers, entities, nested plain structs) are stored as they are. Types that
/// hold a `String`, an array or a class instance get lifecycle hooks, so Flecs copies, moves and
/// destroys them through Swift and never loses a reference.
public protocol Component {}

/// What a world remembers for its Swift side: the component ids it has registered.
///
/// Stored in Flecs' binding context, so it is reachable from any stage of the world and freed
/// with it.
final class WorldContext {
    var componentIds: [ObjectIdentifier: ecs_entity_t] = [:]
    /// False once the world has been destroyed, for objects that outlive it (a ``Query`` kept
    /// past its world) and must not touch Flecs any more.
    var isAlive = true
}

extension WorldAccess where Self: ~Copyable {
    /// The id Flecs gave `type` in this world, registering it on first use.
    @usableFromInline
    func componentId<T: Component>(_ type: T.Type) -> ecs_entity_t {
        let context = self.context
        let key = ObjectIdentifier(type)
        if let id = context.componentIds[key] {
            return id
        }
        let id = registerComponent(type)
        context.componentIds[key] = id
        return id
    }

    private func registerComponent<T: Component>(_ type: T.Type) -> ecs_entity_t {
        // Components live at the root, under their qualified type name, whatever the current scope.
        let previousScope = ecs_set_scope(flecsWorld, 0)
        defer { _ = ecs_set_scope(flecsWorld, previousScope) }

        let size = MemoryLayout<T>.size == 0 ? 0 : MemoryLayout<T>.stride
        let id = componentName(for: type).withCString { name in
            var entityDesc = ecs_entity_desc_t()
            entityDesc.name = name
            entityDesc.symbol = name
            entityDesc.use_low_id = true
            var componentDesc = ecs_component_desc_t()
            componentDesc.entity = ecs_entity_init(flecsWorld, &entityDesc)
            // A tag is size 0 and alignment 0; Flecs rejects one without the other.
            componentDesc.type.size = Int32(size)
            componentDesc.type.alignment = size == 0 ? 0 : Int32(MemoryLayout<T>.alignment)
            return ecs_component_init(flecsWorld, &componentDesc)
        }
        precondition(id != 0, "Flecs refused to register component \(type)")
        if size > 0, !_isPOD(type) {
            installLifecycle(type, id: id)
        }
        return id
    }

    private func installLifecycle<T: Component>(_ type: T.Type, id: ecs_entity_t) {
        var hooks = ecs_type_hooks_t()
        // Swift types have no universal default initializer; values arrive through
        // emplace + initialize, so constructing in place is an error.
        hooks.flags = screamHookCtorIllegal()
        hooks.dtor = destroyThunk
        hooks.copy = copyAssignThunk
        hooks.copy_ctor = copyConstructThunk
        hooks.move = moveAssignThunk
        hooks.move_ctor = moveConstructThunk
        hooks.ctor_move_dtor = moveConstructDestroyThunk
        hooks.move_dtor = moveAssignDestroyThunk
        hooks.binding_ctx = Unmanaged.passRetained(Lifecycle(type)).toOpaque()
        hooks.binding_ctx_free = releaseLifecycle
        ecs_set_hooks_id(flecsWorld, id, &hooks)
    }
}

/// Flecs' path to a Swift type: `Game.Position`, with everything that is not a name made safe.
///
/// `.` is Flecs' path separator, so the module and nesting dots stay and become scopes. Inside
/// generic arguments every other character becomes `_`, so `Game.Health<Game.Player>` is the
/// entity `Health_Game_Player_` in scope `Game`.
func componentName<T>(for type: T.Type) -> String {
    var name = ""
    var depth = 0
    for character in String(reflecting: type) {
        switch character {
        case "<":
            depth += 1
            name.append("_")
        case ">":
            depth -= 1
            name.append("_")
        case "." where depth == 0:
            name.append(".")
        case _ where character.isLetter || character.isNumber || character == "_":
            name.append(character)
        default:
            name.append("_")
        }
    }
    return name
}

/// The Swift operations Flecs' hooks call for one component type, found through the hook context.
///
/// Flecs' `move` leaves the source valid (it destroys it later), so for Swift's copyable types it
/// is a copy; the `...dtor` variants consume the source, so they are real moves.
final class Lifecycle {
    let destroy: (UnsafeMutableRawPointer, Int) -> Void
    let copyAssign: (UnsafeMutableRawPointer, UnsafeRawPointer, Int) -> Void
    let copyConstruct: (UnsafeMutableRawPointer, UnsafeRawPointer, Int) -> Void
    let moveAssign: (UnsafeMutableRawPointer, UnsafeMutableRawPointer, Int) -> Void
    let moveConstruct: (UnsafeMutableRawPointer, UnsafeMutableRawPointer, Int) -> Void
    let moveConstructDestroy: (UnsafeMutableRawPointer, UnsafeMutableRawPointer, Int) -> Void
    let moveAssignDestroy: (UnsafeMutableRawPointer, UnsafeMutableRawPointer, Int) -> Void

    init<T>(_ type: T.Type) {
        destroy = { pointer, count in
            pointer.assumingMemoryBound(to: T.self).deinitialize(count: count)
        }
        copyAssign = { destination, source, count in
            let destination = destination.assumingMemoryBound(to: T.self)
            let source = source.assumingMemoryBound(to: T.self)
            for index in 0..<count {
                destination[index] = source[index]
            }
        }
        copyConstruct = { destination, source, count in
            destination.assumingMemoryBound(to: T.self)
                .initialize(from: source.assumingMemoryBound(to: T.self), count: count)
        }
        moveAssign = { destination, source, count in
            let destination = destination.assumingMemoryBound(to: T.self)
            let source = source.assumingMemoryBound(to: T.self)
            for index in 0..<count {
                destination[index] = source[index]
            }
        }
        moveConstruct = { destination, source, count in
            destination.assumingMemoryBound(to: T.self)
                .initialize(from: source.assumingMemoryBound(to: T.self), count: count)
        }
        moveConstructDestroy = { destination, source, count in
            destination.assumingMemoryBound(to: T.self)
                .moveInitialize(from: source.assumingMemoryBound(to: T.self), count: count)
        }
        moveAssignDestroy = { destination, source, count in
            destination.assumingMemoryBound(to: T.self)
                .moveUpdate(from: source.assumingMemoryBound(to: T.self), count: count)
        }
    }

    static func from(_ typeInfo: UnsafePointer<ecs_type_info_t>?) -> Lifecycle {
        guard let context = typeInfo?.pointee.hooks.binding_ctx else {
            fatalError("Flecs called a Scream lifecycle hook for a component Scream did not register")
        }
        return Unmanaged<Lifecycle>.fromOpaque(context).takeUnretainedValue()
    }
}

private let releaseLifecycle: @convention(c) (UnsafeMutableRawPointer?) -> Void = { context in
    guard let context else { return }
    Unmanaged<Lifecycle>.fromOpaque(context).release()
}

private let destroyThunk: ecs_xtor_t = { pointer, count, typeInfo in
    guard let pointer, count > 0 else { return }
    Lifecycle.from(typeInfo).destroy(pointer, Int(count))
}

private let copyAssignThunk: ecs_copy_t = { destination, source, count, typeInfo in
    guard let destination, let source, count > 0 else { return }
    Lifecycle.from(typeInfo).copyAssign(destination, source, Int(count))
}

private let copyConstructThunk: ecs_copy_t = { destination, source, count, typeInfo in
    guard let destination, let source, count > 0 else { return }
    Lifecycle.from(typeInfo).copyConstruct(destination, source, Int(count))
}

private let moveAssignThunk: ecs_move_t = { destination, source, count, typeInfo in
    guard let destination, let source, count > 0 else { return }
    Lifecycle.from(typeInfo).moveAssign(destination, source, Int(count))
}

private let moveConstructThunk: ecs_move_t = { destination, source, count, typeInfo in
    guard let destination, let source, count > 0 else { return }
    Lifecycle.from(typeInfo).moveConstruct(destination, source, Int(count))
}

private let moveConstructDestroyThunk: ecs_move_t = { destination, source, count, typeInfo in
    guard let destination, let source, count > 0 else { return }
    Lifecycle.from(typeInfo).moveConstructDestroy(destination, source, Int(count))
}

private let moveAssignDestroyThunk: ecs_move_t = { destination, source, count, typeInfo in
    guard let destination, let source, count > 0 else { return }
    Lifecycle.from(typeInfo).moveAssignDestroy(destination, source, Int(count))
}
