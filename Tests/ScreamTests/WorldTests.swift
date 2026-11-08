import Scream
import Testing

@Suite("World")
struct WorldTests {
    @Test("Creates a world, runs a frame and quits")
    func lifecycle() {
        let world = World()
        let ranFrame = world.progress()
        #expect(ranFrame)
        let before = world.shouldQuit
        #expect(before == false)
        world.quit()
        let after = world.shouldQuit
        #expect(after)
        let ranAfterQuit = world.progress()
        #expect(ranAfterQuit == false)
    }
}
