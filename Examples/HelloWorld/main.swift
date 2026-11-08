// The smallest Scream program: two components, a system, a few frames.
import Scream

struct Position: Component {
    var x: Double
    var y: Double
}

struct Velocity: Component {
    var x: Double
    var y: Double
}

let world = World()

// Runs once per entity that has both components, every frame, in the OnUpdate phase.
world.system(InOut<Position>.self, In<Velocity>.self, name: "Move") { iteration, _, position, velocity in
    position.x += velocity.x * Double(iteration.deltaTime)
    position.y += velocity.y * Double(iteration.deltaTime)
}

let bob = world.entity("Bob")
world.set(bob, Position(x: 0, y: 0))
world.set(bob, Velocity(x: 1, y: 2))

let alice = world.entity("Alice")
world.set(alice, Position(x: 10, y: 20))
world.set(alice, Velocity(x: -1, y: 0))

for frame in 1...3 {
    world.progress(deltaTime: 0.5)
    print("Frame \(frame):")
    world.query(In<Position>.self).each { entity, position in
        print("  \(world.name(of: entity) ?? "?") is at \(position.x), \(position.y)")
    }
}
