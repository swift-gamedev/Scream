// Balls as entities: Scream moves and bounces them, Swaylib draws them. Click to add more.
//
// The frame loop belongs to Swaylib; the world runs one frame inside each drawing block, so the
// render system in the OnStore phase draws while the frame is open.
import Scream
import Swaylib

struct Position: Component {
    var x: Float
    var y: Float
}

struct Velocity: Component {
    var x: Float
    var y: Float
}

struct Ball: Component {
    var radius: Float
    var color: Color
}

let colors: [Color] = [.maroon, .orange, .darkGreen, .darkBlue, .purple, .gold, .skyBlue, .lime]

var window = try Window(width: 800, height: 450, title: "Scream + Swaylib: bouncing balls", flags: [.windowResizable])
window.targetFPS = 60

let world = World()
// The window cannot be captured by the system closures (it owns the context), so they read this.
var screen = window.size

@MainActor
func addBall(at position: Vector2) {
    let ball = world.entity()
    world.set(ball, Position(x: position.x, y: position.y))
    world.set(ball, Velocity(x: Float.random(in: -200...200), y: Float.random(in: -200...200)))
    world.set(ball, Ball(radius: Float.random(in: 6...18), color: colors.randomElement() ?? .maroon))
}

for _ in 0..<50 {
    addBall(at: Vector2(Float.random(in: 50...750), Float.random(in: 50...400)))
}

world.system(InOut<Position>.self, In<Velocity>.self, name: "Move") { iteration, _, position, velocity in
    position.x += velocity.x * iteration.deltaTime
    position.y += velocity.y * iteration.deltaTime
}

// Point the velocity back inward at an edge and keep the ball inside, which also recovers balls
// the window shrank past.
world.system(InOut<Position>.self, InOut<Velocity>.self, In<Ball>.self, name: "Bounce") { position, velocity, ball in
    let low = ball.radius
    let highX = max(low, screen.x - ball.radius)
    let highY = max(low, screen.y - ball.radius)
    if position.x <= low {
        velocity.x = abs(velocity.x)
    } else if position.x >= highX {
        velocity.x = -abs(velocity.x)
    }
    if position.y <= low {
        velocity.y = abs(velocity.y)
    } else if position.y >= highY {
        velocity.y = -abs(velocity.y)
    }
    position.x = min(max(position.x, low), highX)
    position.y = min(max(position.y, low), highY)
}

world.system(In<Position>.self, In<Ball>.self, name: "Render", phase: .onStore) { position, ball in
    Draw.circle(center: Vector2(position.x, position.y), radius: ball.radius, color: ball.color)
}

while !window.shouldClose {
    screen = window.size
    if Mouse.isPressed(.left) {
        addBall(at: Mouse.position)
    }
    drawing {
        Draw.clearBackground(.rayWhite)
        world.progress(deltaTime: Time.frame)
        Draw.text("\(world.count(Ball.self)) balls, click to add", x: 10, y: window.height - 25, color: .darkGray)
        Draw.fps(x: 10, y: 10)
    }
}
