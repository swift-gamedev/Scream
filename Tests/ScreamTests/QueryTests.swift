import Scream
import Testing

@Suite("Queries")
struct QueryTests {
    @Test("Matches entities with every term and delivers typed accessors")
    func each() {
        let world = World()
        for index in 0..<10 {
            let entity = world.entity()
            world.set(entity, Position(x: Double(index), y: 0))
            if index < 5 {
                world.set(entity, Velocity(x: 1, y: 2))
            }
        }
        let movers = world.query(InOut<Position>.self, In<Velocity>.self)
        let count = movers.count
        #expect(count == 5)
        let empty = movers.isEmpty
        #expect(empty == false)

        var visited = 0
        movers.each { position, velocity in
            position.x += velocity.x
            position.y += velocity.y
            visited += 1
        }
        #expect(visited == 5)

        var total = 0.0
        let positions = world.query(In<Position>.self)
        positions.each { position in
            total += position.y
        }
        #expect(total == 10)
    }

    @Test("Delivers the entity and the iteration")
    func entities() {
        let world = World()
        let a = world.entity("A")
        let b = world.entity("B")
        world.set(a, Health(points: 1))
        world.set(b, Health(points: 2))

        var seen: [Entity: Int] = [:]
        world.query(In<Health>.self).each { entity, health in
            seen[entity] = health.points
        }
        #expect(seen == [a: 1, b: 2])

        var rows = 0
        world.query(In<Health>.self).each { iteration, entity, health in
            rows += 1
            // Both entities have the same components, so they share a table and a batch.
            let batch = iteration.count
            #expect(batch == 2)
            let samePoints = health.value.points == seen[entity]
            #expect(samePoints)
        }
        #expect(rows == 2)
    }

    @Test("Filters narrow the match without delivering data")
    func filters() {
        let world = World()
        let parent = world.entity("Parent")
        let player = world.entity()
        world.set(player, Position(x: 1, y: 1))
        world.add(player, Player.self)
        let child = world.entity()
        world.set(child, Position(x: 2, y: 2))
        world.add(child, .childOf(parent))
        let other = world.entity()
        world.set(other, Position(x: 3, y: 3))

        let players = world.query(In<Position>.self, filter: [.with(Player.self)])
        let playerCount = players.count
        #expect(playerCount == 1)

        let children = world.query(In<Position>.self, filter: [.with(.childOf(parent))])
        let childCount = children.count
        #expect(childCount == 1)

        let loners = world.query(
            In<Position>.self, filter: [.without(Player.self), .without(Pair(.childOf, .wildcard))])
        var lonerX = 0.0
        loners.each { position in
            lonerX = position.x
        }
        #expect(lonerX == 3)
    }

    @Test("Shared components from a prefab read the same value for every instance")
    func shared() {
        let world = World()
        // Keep the velocity on the prefab rather than copying it to instances. Flecs only lets
        // this trait change before the component is used.
        world.add(world.component(Velocity.self), Pair(.onInstantiate, .inherit))
        let prefab = world.prefab("Base")
        world.set(prefab, Velocity(x: 7, y: 0))
        for _ in 0..<3 {
            let instance = world.entity()
            world.add(instance, .isA(prefab))
            world.set(instance, Position(x: 0, y: 0))
        }
        world.query(InOut<Position>.self, In<Velocity>.self).each { position, velocity in
            position.x += velocity.x
        }
        var moved = 0
        world.query(In<Position>.self).each { position in
            if position.x == 7 {
                moved += 1
            }
        }
        #expect(moved == 3)
    }

    @Test("Prints itself in Flecs' query language")
    func description() {
        let world = World()
        let query = world.query(In<Position>.self, filter: [.without(Player.self)])
        let text = query.description
        #expect(text.contains("Position"))
        #expect(text.contains("!"))
    }

    @Test("Outlives its world without touching it")
    func outlivesWorld() {
        var kept: Query<Terms1<In<Position>>>?
        do {
            let world = World()
            kept = world.query(In<Position>.self)
            let count = kept?.count
            #expect(count == 0)
        }
        // Dropping the query after the world must not call into freed Flecs memory.
        kept = nil
    }
}
