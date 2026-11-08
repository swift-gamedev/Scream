import CFlecs
import CFlecsShims
import Scream
import Testing

@Suite("Vendored Flecs")
struct CFlecsTests {
    @Test("Reports the vendored release")
    func version() {
        #expect(flecsVersion == "4.2.0")
        #expect(FLECS_VERSION_MAJOR == 4)
        #expect(FLECS_VERSION_MINOR == 2)
    }

    // Worlds are created through the shim, which serializes Flecs' OS API setup; the tests run
    // in parallel and plain ecs_init calls would race.
    @Test("Creates and destroys a world through the C API")
    func cWorld() {
        let world = screamInitWorld()
        #expect(world != nil)
        #expect(ecs_progress(world, 0))
        #expect(screamFiniWorld(world) == 0)
    }

    @Test("Builds pairs through the shims")
    func pairs() {
        let pair = screamPair(EcsChildOf, EcsFlecs)
        #expect(screamIdIsPair(pair))
        let world = screamInitWorld()
        #expect(screamPairFirst(world, pair) == EcsChildOf)
        #expect(screamPairSecond(world, pair) == EcsFlecs)
        _ = screamFiniWorld(world)
    }
}

@Suite("Struct layout")
struct LayoutTests {
    // Swift always imports Flecs' debug layout, while the C compile sees NDEBUG in release builds.
    // Every struct Swift holds by value must have the same size and alignment in both.
    @Test("Matches the C compiler for every struct held by value")
    func matchesC() {
        #expect(MemoryLayout<ecs_iter_t>.size == screamSizeOf_ecs_iter_t())
        #expect(MemoryLayout<ecs_iter_t>.alignment == screamAlignOf_ecs_iter_t())
        #expect(MemoryLayout<ecs_query_desc_t>.size == screamSizeOf_ecs_query_desc_t())
        #expect(MemoryLayout<ecs_query_desc_t>.alignment == screamAlignOf_ecs_query_desc_t())
        #expect(MemoryLayout<ecs_system_desc_t>.size == screamSizeOf_ecs_system_desc_t())
        #expect(MemoryLayout<ecs_system_desc_t>.alignment == screamAlignOf_ecs_system_desc_t())
        #expect(MemoryLayout<ecs_observer_desc_t>.size == screamSizeOf_ecs_observer_desc_t())
        #expect(MemoryLayout<ecs_observer_desc_t>.alignment == screamAlignOf_ecs_observer_desc_t())
        #expect(MemoryLayout<ecs_component_desc_t>.size == screamSizeOf_ecs_component_desc_t())
        #expect(MemoryLayout<ecs_component_desc_t>.alignment == screamAlignOf_ecs_component_desc_t())
        #expect(MemoryLayout<ecs_entity_desc_t>.size == screamSizeOf_ecs_entity_desc_t())
        #expect(MemoryLayout<ecs_entity_desc_t>.alignment == screamAlignOf_ecs_entity_desc_t())
        #expect(MemoryLayout<ecs_type_hooks_t>.size == screamSizeOf_ecs_type_hooks_t())
        #expect(MemoryLayout<ecs_type_hooks_t>.alignment == screamAlignOf_ecs_type_hooks_t())
        #expect(MemoryLayout<ecs_type_info_t>.size == screamSizeOf_ecs_type_info_t())
        #expect(MemoryLayout<ecs_type_info_t>.alignment == screamAlignOf_ecs_type_info_t())
        #expect(MemoryLayout<ecs_term_t>.size == screamSizeOf_ecs_term_t())
        #expect(MemoryLayout<ecs_term_t>.alignment == screamAlignOf_ecs_term_t())
        #expect(MemoryLayout<ecs_term_ref_t>.size == screamSizeOf_ecs_term_ref_t())
        #expect(MemoryLayout<ecs_term_ref_t>.alignment == screamAlignOf_ecs_term_ref_t())
        #expect(MemoryLayout<ecs_world_info_t>.size == screamSizeOf_ecs_world_info_t())
        #expect(MemoryLayout<ecs_world_info_t>.alignment == screamAlignOf_ecs_world_info_t())
    }
}
