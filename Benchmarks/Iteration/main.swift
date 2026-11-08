// How much the typed Swift API costs over the C API for the hot loop: one million entities with
// a position and a velocity, moved for a number of frames three ways. Run it in release:
//
//   swift run -c release IterationBenchmark
//
// Debug builds are not meaningful; generics are not specialized there.
import CFlecs
import Scream

struct Position: Component {
    var x: Double
    var y: Double
}

struct Velocity: Component {
    var x: Double
    var y: Double
}

let entityCount = 1_000_000
let frames = 50

let world = World()
for index in 0..<entityCount {
    let entity = world.entity()
    world.set(entity, Position(x: Double(index), y: 0))
    world.set(entity, Velocity(x: 1, y: 0.5))
}

let clock = ContinuousClock()

/// `duration` in nanoseconds.
func nanoseconds(_ duration: Duration) -> Double {
    Double(duration.components.seconds) * 1e9 + Double(duration.components.attoseconds) / 1e9
}

/// `value` with two decimals, without Foundation.
func twoDecimals(_ value: Double) -> String {
    let hundredths = Int((value * 100).rounded())
    let fraction = hundredths % 100
    return "\(hundredths / 100).\(fraction < 10 ? "0" : "")\(fraction)"
}

func report(_ name: String, _ duration: Duration) {
    let perEntity = nanoseconds(duration) / Double(entityCount * frames)
    print("\(name): \(twoDecimals(perEntity)) ns per entity")
}

// Scream: a typed query iterated with per-entity accessors.
let query = world.query(InOut<Position>.self, In<Velocity>.self)
let screamQuery = clock.measure {
    for _ in 0..<frames {
        query.each { position, velocity in
            position.x += velocity.x
            position.y += velocity.y
        }
    }
}
report("Scream query.each", screamQuery)

// Scream: the same loop as a system run by progress.
world.system(InOut<Position>.self, In<Velocity>.self, name: "Move") { position, velocity in
    position.x += velocity.x
    position.y += velocity.y
}
let screamSystem = clock.measure {
    for _ in 0..<frames {
        world.progress()
    }
}
report("Scream system", screamSystem)

// C: the same query through Flecs' C API, with raw pointers into the columns.
var desc = ecs_query_desc_t()
withUnsafeMutablePointer(to: &desc.terms) { tuple in
    tuple.withMemoryRebound(to: ecs_term_t.self, capacity: Int(FLECS_TERM_COUNT_MAX)) { terms in
        terms[0].id = world.component(Position.self).rawValue
        terms[0].inout = Int16(EcsInOut.rawValue)
        terms[1].id = world.component(Velocity.self).rawValue
        terms[1].inout = Int16(EcsIn.rawValue)
    }
}
guard let cQuery = ecs_query_init(world.flecsWorld, &desc) else {
    fatalError("query failed")
}
let cLoop = clock.measure {
    for _ in 0..<frames {
        var iterator = ecs_query_iter(world.flecsWorld, cQuery)
        while ecs_query_next(&iterator) {
            guard let positionColumn = ecs_field_w_size(&iterator, MemoryLayout<Position>.stride, 0),
                let velocityColumn = ecs_field_w_size(&iterator, MemoryLayout<Velocity>.stride, 1)
            else { fatalError("field missing") }
            let positions = positionColumn.assumingMemoryBound(to: Position.self)
            let velocities = velocityColumn.assumingMemoryBound(to: Velocity.self)
            for row in 0..<Int(iterator.count) {
                positions[row].x += velocities[row].x
                positions[row].y += velocities[row].y
            }
        }
    }
}
report("C API loop", cLoop)
ecs_query_fini(cQuery)

let ratio = nanoseconds(screamQuery) / nanoseconds(cLoop)
print("Scream query.each takes \(twoDecimals(ratio))x the time of the C loop")
