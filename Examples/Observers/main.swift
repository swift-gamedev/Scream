// Observers react to changes; systems run every frame. Here both work on the same components.
import Scream

struct Health: Component {
    var points: Int
}

struct Poisoned: Component {
    var perFrame: Int
}

/// A tag that an observer adds when health runs out.
struct Dead: Component {}

let world = World()

// Observers run right away outside a frame, and when the frame's changes are merged inside one.
world.observer(In<Health>.self, events: [.onSet]) { iteration, entity, health in
    let name = iteration.stage.name(of: entity) ?? "?"
    print("  \(name) now has \(health.points) HP")
    if health.points <= 0 {
        iteration.stage.add(entity, Dead.self)
    }
}

world.observer(In<Health>.self, events: [.onRemove], filter: [.with(Dead.self)]) { iteration, entity, _ in
    print("  \(iteration.stage.name(of: entity) ?? "?") is gone")
}

// The poison system lowers health through the stage, so the observer above sees each change.
world.system(In<Health>.self, In<Poisoned>.self, name: "Poison", filter: [.without(Dead.self)]) {
    iteration, entity, health, poison in
    iteration.stage.set(entity, Health(points: health.points - poison.perFrame))
}

// A cleanup system in a later phase removes the dead.
world.system(In<Health>.self, name: "Bury", phase: .postUpdate, filter: [.with(Dead.self)]) { iteration, entity, _ in
    iteration.stage.delete(entity)
}

let rat = world.entity("Rat")
print("Setup:")
world.set(rat, Health(points: 5))
world.set(rat, Poisoned(perFrame: 2))

var frame = 0
while world.count(Health.self) > 0 {
    frame += 1
    print("Frame \(frame):")
    world.progress()
}
print("Done after \(frame) frames.")
