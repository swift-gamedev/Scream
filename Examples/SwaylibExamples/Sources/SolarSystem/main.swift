// A hierarchy of orbits: planets are children of the sun, moons children of planets. Each body's
// position comes from its orbit around its parent's position, and Swaylib draws the result.
import Foundation  // sin and cos
import Scream
import Swaylib

/// An orbit around the parent entity.
struct Orbit: Component {
    var radius: Float
    var speed: Float
    var angle: Float
}

/// Where the body is on screen this frame.
struct WorldPosition: Component {
    var x: Float
    var y: Float
}

struct Body: Component {
    var radius: Float
    var color: Color
}

/// Tags for the two depths, so the planets' positions are computed before the moons'.
struct Planet: Component {}
struct Moon: Component {}

var window = try Window(width: 800, height: 600, title: "Scream + Swaylib: solar system")
window.targetFPS = 60

let world = World()
var center = window.size / 2

let sun = world.entity("Sun")
world.set(sun, WorldPosition(x: center.x, y: center.y))
world.set(sun, Body(radius: 30, color: .gold))

let planets: [(name: String, radius: Float, speed: Float, size: Float, color: Color, moons: Int)] = [
    ("Mercury", 60, 1.6, 4, .gray, 0),
    ("Venus", 90, 1.2, 7, .beige, 0),
    ("Earth", 130, 1.0, 8, .blue, 1),
    ("Mars", 170, 0.8, 6, .red, 2),
    ("Jupiter", 240, 0.4, 18, .orange, 4),
]
for planet in planets {
    let entity = world.entity(planet.name, parent: sun)
    world.add(entity, Planet.self)
    world.set(entity, Orbit(radius: planet.radius, speed: planet.speed, angle: Float.random(in: 0..<6.28)))
    world.set(entity, WorldPosition(x: 0, y: 0))
    world.set(entity, Body(radius: planet.size, color: planet.color))
    for index in 0..<planet.moons {
        let moon = world.entity("Moon\(index + 1)", parent: entity)
        world.add(moon, Moon.self)
        world.set(moon, Orbit(radius: planet.size + 8 + Float(index) * 7, speed: 3 - Float(index) * 0.5, angle: 0))
        world.set(moon, WorldPosition(x: 0, y: 0))
        world.set(moon, Body(radius: 2, color: .lightGray))
    }
}

world.system(InOut<Orbit>.self, name: "Advance") { iteration, _, orbit in
    orbit.angle += orbit.speed * iteration.deltaTime
}

// The same computation twice, planets first, so each body's parent is already placed.
func place(_ iteration: Iteration, _ entity: Entity, _ orbit: Ref<Orbit>, _ position: Mut<WorldPosition>) {
    let stage = iteration.stage
    guard let parent = stage.parent(of: entity), let anchor = stage.get(parent, WorldPosition.self) else { return }
    position.x = anchor.x + orbit.radius * cos(orbit.angle)
    position.y = anchor.y + orbit.radius * sin(orbit.angle)
}
world.system(In<Orbit>.self, Out<WorldPosition>.self, name: "PlacePlanets", filter: [.with(Planet.self)]) {
    iteration, entity, orbit, position in
    place(iteration, entity, orbit, position)
}
world.system(In<Orbit>.self, Out<WorldPosition>.self, name: "PlaceMoons", filter: [.with(Moon.self)]) {
    iteration, entity, orbit, position in
    place(iteration, entity, orbit, position)
}

world.system(In<WorldPosition>.self, In<Body>.self, name: "Render", phase: .onStore) { position, body in
    Draw.circle(center: Vector2(position.x, position.y), radius: body.radius, color: body.color)
}

while !window.shouldClose {
    center = window.size / 2
    world.set(sun, WorldPosition(x: center.x, y: center.y))
    drawing {
        Draw.clearBackground(.black)
        world.progress(deltaTime: Time.frame)
        Draw.text("\(world.count(Body.self)) bodies in a ChildOf hierarchy", x: 10, y: 10, color: .lightGray)
    }
}
