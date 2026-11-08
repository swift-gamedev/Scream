import Scream
import Testing

@Suite("Entities")
struct EntityTests {
    @Test("Creates, names and looks up entities")
    func naming() {
        let world = World()
        let anonymous = world.entity()
        let anonymousName = world.name(of: anonymous)
        #expect(anonymousName == nil)
        let anonymousPath = world.path(of: anonymous)
        #expect(anonymousPath == nil)

        let bob = world.entity("Bob")
        let bobName = world.name(of: bob)
        #expect(bobName == "Bob")
        let found = world.lookup("Bob")
        #expect(found == bob)
        let again = world.entity("Bob")
        #expect(again == bob)
        let missing = world.lookup("Alice")
        #expect(missing == nil)

        world.setName(bob, "Robert")
        let renamed = world.name(of: bob)
        #expect(renamed == "Robert")
    }

    @Test("Paths follow the hierarchy")
    func paths() {
        let world = World()
        let parent = world.entity("Parent")
        let child = world.entity("Child", parent: parent)
        let childPath = world.path(of: child)
        #expect(childPath == "Parent.Child")
        let byPath = world.lookup("Parent.Child")
        #expect(byPath == child)
        let grandchild = world.entity("Parent.Child.Grandchild")
        let grandchildParent = world.parent(of: grandchild)
        #expect(grandchildParent == child)
        let children = world.children(of: parent)
        #expect(children == [child])
        let hasChildOf = world.has(child, .childOf(parent))
        #expect(hasChildOf)
        let hasAnyParent = world.has(child, Pair(.childOf, .wildcard))
        #expect(hasAnyParent)
    }

    @Test("Deleting an entity takes its children and frees the id")
    func deletion() {
        let world = World()
        let parent = world.entity()
        let child = world.entity()
        world.add(child, .childOf(parent))
        let bothAlive = world.isAlive(parent) && world.isAlive(child)
        #expect(bothAlive)
        world.delete(parent)
        let parentAlive = world.isAlive(parent)
        #expect(parentAlive == false)
        let childAlive = world.isAlive(child)
        #expect(childAlive == false)
        // Flecs recycles the id with a new generation, so the old value stays dead.
        let recycled = world.entity()
        #expect(recycled != parent)
        let recycledAlive = world.isAlive(recycled)
        #expect(recycledAlive)
    }

    @Test("Tags, pairs and ids")
    func tags() {
        let world = World()
        let likes = world.entity("Likes")
        let apples = world.entity("Apples")
        let bob = world.entity()
        world.add(bob, Pair(likes, apples))
        let likesApples = world.has(bob, Pair(likes, apples))
        #expect(likesApples)
        let target = world.target(of: bob, likes)
        #expect(target == apples)

        let ids = world.type(of: bob)
        #expect(ids.count == 1)
        let first = ids[0]
        #expect(first.isPair)
        let pair = world.pair(of: first)
        #expect(pair == Pair(likes, apples))
        #expect(first.pair?.second.rawValue == apples.rawValue & 0xFFFF_FFFF)

        world.remove(bob, Pair(likes, apples))
        let stillLikes = world.has(bob, Pair(likes, apples))
        #expect(stillLikes == false)

        let tag = world.entity("Tag")
        world.add(bob, tag)
        let hasTag = world.has(bob, Id(tag))
        #expect(hasTag)
        let tagId = world.type(of: bob)[0]
        #expect(tagId.entity == tag)
        #expect(tagId.pair == nil)
    }

    @Test("Enabling and disabling")
    func enabling() {
        let world = World()
        let entity = world.entity()
        let enabled = world.isEnabled(entity)
        #expect(enabled)
        world.setEnabled(entity, false)
        let disabled = world.isEnabled(entity)
        #expect(disabled == false)
        world.setEnabled(entity, true)
        let reenabled = world.isEnabled(entity)
        #expect(reenabled)
    }

    @Test("Prefabs pass their components on")
    func prefabs() {
        let world = World()
        let base = world.prefab("Base")
        world.set(base, Health(points: 100))
        let hasPrefabTag = world.has(base, Entity.prefab)
        #expect(hasPrefabTag)

        let instance = world.entity()
        world.add(instance, .isA(base))
        let inherited = world.get(instance, Health.self)
        #expect(inherited?.points == 100)
        let hasHealth = world.has(instance, Health.self)
        #expect(hasHealth)
        // Flecs 4 copies inherited components to the instance by default (OnInstantiate is
        // Override), so both the prefab and the instance own a Health.
        let owners = world.count(Health.self)
        #expect(owners == 2)
        world.modify(instance, Health.self) { $0.points = 50 }
        let baseUnchanged = world.get(base, Health.self)
        #expect(baseUnchanged?.points == 100)
    }

    @Test("Stages queue writes until merged")
    func deferred() {
        let world = World()
        let entity = world.entity()
        world.deferred { stage in
            stage.set(entity, Health(points: 5))
            let notYet = world.has(entity, Health.self)
            #expect(notYet == false)
        }
        let merged = world.get(entity, Health.self)
        #expect(merged?.points == 5)
    }
}
