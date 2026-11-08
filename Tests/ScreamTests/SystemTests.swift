import Scream
import Testing

@Suite("Systems")
struct SystemTests {
    @Test("Runs every frame in phase order")
    func phases() {
        let world = World()
        let entity = world.entity()
        world.set(entity, Position(x: 0, y: 0))
        world.set(entity, Velocity(x: 1, y: 0))

        final class Trace {
            var steps: [String] = []
        }
        let trace = Trace()

        world.system(InOut<Position>.self, In<Velocity>.self, name: "Move") { position, velocity in
            position.x += velocity.x
            trace.steps.append("move")
        }
        world.system(In<Position>.self, name: "Report", phase: .postUpdate) { position in
            trace.steps.append("report \(position.x)")
        }
        world.system(In<Position>.self, name: "Load", phase: .onLoad) { _ in
            trace.steps.append("load")
        }

        world.progress()
        #expect(trace.steps == ["load", "move", "report 1.0"])
        world.progress()
        let moved = world.get(entity, Position.self)
        #expect(moved == Position(x: 2, y: 0))

        let system = world.lookup("Move")
        #expect(system != nil)
    }

    @Test("Passes the frame's time step")
    func deltaTime() {
        let world = World()
        world.set(world.entity(), Health(points: 0))
        var seen: Float = 0
        world.system(InOut<Health>.self) { iteration, _, health in
            seen = iteration.deltaTime
            health.points += 1
        }
        world.progress(deltaTime: 0.25)
        #expect(seen == 0.25)
        let worldDelta = world.deltaTime
        #expect(worldDelta == 0.25)
    }

    @Test("Writes through the stage are applied after the systems ran")
    func stageWrites() {
        let world = World()
        for index in 0..<4 {
            let entity = world.entity()
            world.set(entity, Health(points: index))
        }
        world.system(In<Health>.self, name: "Cull") { iteration, entity, health in
            if health.points == 0 {
                iteration.stage.delete(entity)
            } else {
                iteration.stage.add(entity, Player.self)
            }
        }
        world.progress()
        let remaining = world.count(Health.self)
        #expect(remaining == 3)
        let players = world.count(Player.self)
        #expect(players == 3)
    }

    @Test("Runs by hand, with an interval, and can be disabled")
    func control() {
        let world = World()
        world.set(world.entity(), Health(points: 0))
        var runs = 0
        let system = world.system(In<Health>.self) { _ in
            runs += 1
        }
        world.run(system)
        #expect(runs == 1)

        world.setEnabled(system, false)
        world.progress()
        #expect(runs == 1)
        world.setEnabled(system, true)
        world.progress()
        #expect(runs == 2)

        world.setInterval(system, seconds: 1)
        world.progress(deltaTime: 0.4)
        world.progress(deltaTime: 0.4)
        #expect(runs == 2)
        world.progress(deltaTime: 0.4)
        #expect(runs == 3)
    }

    @Test("Custom phases slot into the pipeline")
    func customPhase() {
        let world = World()
        world.set(world.entity(), Health(points: 0))
        var order: [String] = []
        let physics = world.phase("Physics", after: .onUpdate)
        world.system(In<Health>.self, phase: physics) { _ in
            order.append("physics")
        }
        world.system(In<Health>.self, phase: .postUpdate) { _ in
            order.append("post")
        }
        world.system(In<Health>.self, phase: .onUpdate) { _ in
            order.append("update")
        }
        world.progress()
        #expect(order == ["update", "physics", "post"])
    }

    @Test("Quit stops the loop")
    func quit() {
        let world = World()
        world.set(world.entity(), Health(points: 0))
        var frames = 0
        world.system(InOut<Health>.self) { iteration, _, health in
            health.points += 1
            frames += 1
            if health.points == 3 {
                iteration.stage.quit()
            }
        }
        while world.progress() {}
        #expect(frames == 3)
    }
}

@Suite("Parallel systems")
struct ParallelSystemTests {
    @Test("Split the entities across threads and get the same result")
    func parallel() {
        let world = World()
        world.setThreads(4)
        let count = 10_000
        for index in 0..<count {
            let entity = world.entity()
            world.set(entity, Position(x: Double(index), y: 0))
            world.set(entity, Velocity(x: 1, y: 1))
        }
        world.parallelSystem(InOut<Position>.self, In<Velocity>.self, name: "Move") { position, velocity in
            position.x += velocity.x
            position.y += velocity.y
        }
        world.progress()
        world.progress()

        var sum = 0.0
        world.query(In<Position>.self).each { position in
            sum += position.y
        }
        #expect(sum == Double(count * 2))
    }
}
