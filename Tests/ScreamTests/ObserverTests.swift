import Scream
import Testing

@Suite("Observers")
struct ObserverTests {
    @Test("Fire on add, set and remove with the values")
    func events() {
        let world = World()
        final class Log {
            var lines: [String] = []
        }
        let log = Log()
        world.observer(In<Health>.self, events: [.onAdd, .onSet, .onRemove]) { iteration, _, health in
            // onAdd runs before the value is written, so the value is only read for the others.
            switch iteration.event {
            case .onAdd: log.lines.append("add")
            case .onSet: log.lines.append("set \(health.points)")
            case .onRemove: log.lines.append("remove \(health.points)")
            default: log.lines.append("other")
            }
        }
        let entity = world.entity()
        world.set(entity, Health(points: 5))
        world.set(entity, Health(points: 6))
        world.remove(entity, Health.self)
        #expect(log.lines == ["add", "set 5", "set 6", "remove 6"])
    }

    @Test("Observe only matching entities and yield existing ones")
    func filtersAndYield() {
        let world = World()
        let player = world.entity()
        world.add(player, Player.self)
        world.set(player, Position(x: 1, y: 1))
        let other = world.entity()
        world.set(other, Position(x: 2, y: 2))

        var seen: [Entity] = []
        world.observer(In<Position>.self, events: [.onSet], filter: [.with(Player.self)], yieldExisting: true) {
            _, entity, _ in
            seen.append(entity)
        }
        #expect(seen == [player])
        world.set(other, Position(x: 3, y: 3))
        world.set(player, Position(x: 4, y: 4))
        #expect(seen == [player, player])
    }

    @Test("Run when a stage merges")
    func deferred() {
        let world = World()
        var sets = 0
        world.observer(In<Health>.self, events: [.onSet]) { _, _, _ in
            sets += 1
        }
        let entity = world.entity()
        world.deferred { stage in
            stage.set(entity, Health(points: 1))
            #expect(sets == 0)
        }
        #expect(sets == 1)
    }
}
