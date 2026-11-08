// Parents and children, prefabs, and what deleting a parent does.
import Scream

struct Position: Component {
    var x: Double
    var y: Double
}

struct Health: Component {
    var points: Int
}

/// A tag for the ships, so a query can pick them out.
struct Ship: Component {}

let world = World()

// A prefab is an entity other entities inherit from. Instances get their own copy of Health.
let shipPrefab = world.prefab("ShipPrefab")
world.set(shipPrefab, Health(points: 100))

// A name with dots is a path, and the parents are created as needed; `parent:` does the same
// relative to an entity. Both add a (ChildOf, parent) pair.
let fleet = world.entity("Fleet")
for name in ["Dawn", "Dusk"] {
    let ship = world.entity("Fleet.\(name)")
    world.add(ship, .isA(shipPrefab))
    world.add(ship, Ship.self)
    world.set(ship, Position(x: 0, y: 0))
    for turret in ["Fore", "Aft"] {
        let child = world.entity(turret, parent: ship)
        world.set(child, Position(x: turret == "Fore" ? 1 : -1, y: 0))
    }
}

// Top-level code runs on the main actor, so a function that reads the world does too.
@MainActor
func describe(_ entity: Entity, depth: Int = 0) {
    let indent = String(repeating: "  ", count: depth)
    let health = world.get(entity, Health.self).map { " (\($0.points) HP)" } ?? ""
    print("\(indent)\(world.path(of: entity) ?? "?")\(health)")
    for child in world.children(of: entity) {
        describe(child, depth: depth + 1)
    }
}

print("The fleet:")
describe(fleet)

// A damaged ship: changing an inherited component changes only that instance.
if let dusk = world.lookup("Fleet.Dusk") {
    world.modify(dusk, Health.self) { $0.points -= 30 }
}
print("\nAfter Dusk took damage:")
world.query(In<Health>.self, filter: [.with(Ship.self)]).each { entity, health in
    print("  \(world.path(of: entity) ?? "?") has \(health.points) HP")
}

// Deleting a parent deletes its children; the ids are recycled with a new generation.
if let dawn = world.lookup("Fleet.Dawn") {
    let turret = world.lookup("Fleet.Dawn.Fore")
    world.delete(dawn)
    print("\nDeleted Dawn. Its turret is alive: \(turret.map { world.isAlive($0) } ?? false)")
}
print("Remaining:")
describe(fleet)
