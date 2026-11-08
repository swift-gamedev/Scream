import Scream
import Testing

@Suite("Components")
struct ComponentTests {
    @Test("Set, get, modify and remove plain data")
    func plainData() {
        let world = World()
        let entity = world.entity()
        let before = world.get(entity, Position.self)
        #expect(before == nil)

        world.set(entity, Position(x: 1, y: 2))
        let position = world.get(entity, Position.self)
        #expect(position == Position(x: 1, y: 2))
        let has = world.has(entity, Position.self)
        #expect(has)

        world.set(entity, Position(x: 3, y: 4))
        let replaced = world.get(entity, Position.self)
        #expect(replaced == Position(x: 3, y: 4))

        let result = world.modify(entity, Position.self) { position -> Double in
            position.x += 10
            return position.x
        }
        #expect(result == 13)
        let modified = world.get(entity, Position.self)
        #expect(modified == Position(x: 13, y: 4))

        let missing = world.modify(entity, Velocity.self) { $0.x = 1 }
        #expect(missing == nil)

        world.remove(entity, Position.self)
        let removed = world.get(entity, Position.self)
        #expect(removed == nil)
    }

    @Test("Tags have no value")
    func tags() {
        let world = World()
        let entity = world.entity()
        world.add(entity, Player.self)
        let isPlayer = world.has(entity, Player.self)
        #expect(isPlayer)
        let players = world.count(Player.self)
        #expect(players == 1)
        world.remove(entity, Player.self)
        let stillPlayer = world.has(entity, Player.self)
        #expect(stillPlayer == false)
    }

    @Test("Components are registered once, at the root, under the type's name")
    func registration() {
        let world = World()
        let component = world.component(Position.self)
        let again = world.component(Position.self)
        #expect(component == again)
        let path = world.path(of: component)
        #expect(path == "ScreamTests.Position")
        let looked = world.lookup("ScreamTests.Position")
        #expect(looked == component)

        let generic = world.component(Slot<Int>.self)
        let genericName = world.name(of: generic)
        #expect(genericName == "Slot_Swift_Int_")
        let other = world.component(Slot<Double>.self)
        #expect(other != generic)
    }

    @Test("Rows are stride apart, not size apart")
    func padding() {
        let world = World()
        var entities: [Entity] = []
        for index in 0..<100 {
            let entity = world.entity()
            world.set(entity, Padded(big: Int64(index), small: Int8(index)))
            entities.append(entity)
        }
        for (index, entity) in entities.enumerated() {
            let value = world.get(entity, Padded.self)
            #expect(value == Padded(big: Int64(index), small: Int8(index)))
        }
    }

    @Test("Pairs carry a component's value per target")
    func pairsWithData() {
        let world = World()
        let gold = world.entity("Gold")
        let silver = world.entity("Silver")
        let shop = world.entity()
        world.set(shop, Health(points: 10), target: gold)
        world.set(shop, Health(points: 20), target: silver)
        let forGold = world.get(shop, Health.self, target: gold)
        #expect(forGold?.points == 10)
        let forSilver = world.get(shop, Health.self, target: silver)
        #expect(forSilver?.points == 20)
        let plain = world.get(shop, Health.self)
        #expect(plain == nil)
        let hasGoldHealth = world.has(shop, Pair(world.component(Health.self), gold))
        #expect(hasGoldHealth)
    }

    @Test("Singletons live on the component's entity")
    func singletons() {
        let world = World()
        let none = world.singleton(Velocity.self)
        #expect(none == nil)
        world.setSingleton(Velocity(x: 1, y: 0))
        let gravity = world.singleton(Velocity.self)
        #expect(gravity == Velocity(x: 1, y: 0))
        let onComponent = world.get(world.component(Velocity.self), Velocity.self)
        #expect(onComponent == Velocity(x: 1, y: 0))
    }

    @Test("Counting and bulk deletion")
    func counting() {
        let world = World()
        for index in 0..<10 {
            let entity = world.entity()
            world.set(entity, Health(points: index))
            if index.isMultiple(of: 2) {
                world.add(entity, Player.self)
            }
        }
        let healthy = world.count(Health.self)
        #expect(healthy == 10)
        let players = world.count(Id(world.component(Player.self)))
        #expect(players == 5)
        world.deleteAll(with: Id(world.component(Player.self)))
        let remaining = world.count(Health.self)
        #expect(remaining == 5)
    }
}

@Suite("Lifecycle hooks")
struct LifecycleTests {
    @Test("Flecs releases every value it copies or moves")
    func releases() {
        let counter = Counter()
        do {
            let world = World()
            let first = world.entity()
            world.set(first, Named(name: "first", token: Token(counter)))
            #expect(counter.live == 1)

            // Replacing destroys the old value.
            world.set(first, Named(name: "second", token: Token(counter)))
            #expect(counter.live == 1)
            let name = world.get(first, Named.self)?.name
            #expect(name == "second")

            // Adding another component moves the row to a new table.
            world.set(first, Position(x: 1, y: 1))
            let moved = world.get(first, Named.self)?.name
            #expect(moved == "second")
            #expect(counter.live == 1)

            // Removing a component from a row in the middle moves the last row into its place.
            let second = world.entity()
            world.set(second, Named(name: "other", token: Token(counter)))
            world.set(second, Position(x: 2, y: 2))
            world.remove(first, Position.self)
            let otherName = world.get(second, Named.self)?.name
            #expect(otherName == "other")
            #expect(counter.live == 2)

            // Deleting destroys.
            world.delete(second)
            #expect(counter.live == 1)

            // Through a stage, the value is moved from the command queue into the table.
            let third = world.entity()
            world.deferred { stage in
                stage.set(third, Named(name: "deferred", token: Token(counter)))
            }
            let deferredName = world.get(third, Named.self)?.name
            #expect(deferredName == "deferred")
            #expect(counter.live == 2)

            // Overriding an inherited value copies it.
            let prefab = world.prefab()
            world.set(prefab, Named(name: "base", token: Token(counter)))
            let instance = world.entity()
            world.add(instance, .isA(prefab))
            world.modify(instance, Named.self) { $0.name = "override" }
            let baseName = world.get(prefab, Named.self)?.name
            #expect(baseName == "base")
            #expect(counter.live == 3)
        }
        // Destroying the world destroys everything left in it.
        #expect(counter.live == 0)
    }

    @Test("Adding a component that is not plain data without a value is an error")
    func addWithoutValueTraps() async {
        await #expect(processExitsWith: .failure) {
            let world = World()
            world.add(world.entity(), Named.self)
        }
    }
}
