import CFlecs
import Scream
import Testing

@Suite("Generated code")
struct GeneratedTests {
    @Test("Enum cases carry Flecs' values")
    func enumValues() {
        #expect(InOutKind.in.rawValue == Int32(EcsIn.rawValue))
        #expect(InOutKind.inOut.rawValue == Int32(EcsInOut.rawValue))
        #expect(InOutKind.out.rawValue == Int32(EcsOut.rawValue))
        #expect(OperatorKind.optional.rawValue == Int32(EcsOptional.rawValue))
        #expect(QueryCacheKind.none.rawValue == Int32(EcsQueryCacheNone.rawValue))
        #expect(PrimitiveKind.bool.rawValue == Int32(EcsBool.rawValue))
    }

    @Test("Builtin entities are Flecs' constants")
    func builtins() {
        #expect(Entity.childOf.rawValue == EcsChildOf)
        #expect(Entity.isA.rawValue == EcsIsA)
        #expect(Entity.onUpdate.rawValue == EcsOnUpdate)
        #expect(Entity.wildcard.rawValue == EcsWildcard)
        #expect(Entity.childOf != Entity.isA)
        #expect(!Entity.childOf.isNull)
        #expect(Entity.null.isNull)
    }
}
