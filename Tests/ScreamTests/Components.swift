import Scream

// Component types shared by the test suites.

struct Position: Component, Equatable {
    var x: Double
    var y: Double
}

struct Velocity: Component, Equatable {
    var x: Double
    var y: Double
}

struct Health: Component, Equatable {
    var points: Int
}

/// A tag: no stored properties.
struct Player: Component {}

/// A tag used as a relationship.
struct Likes: Component {}

/// A component with trailing padding, so its size and stride differ.
struct Padded: Component, Equatable {
    var big: Int64
    var small: Int8
}

/// Not plain data: holds a reference, so Flecs has to go through Swift to copy and destroy it.
struct Named: Component {
    var name: String
    var token: Token
}

/// Counts how many `Token`s are alive, to check that Flecs releases every one.
final class Counter {
    private(set) var live = 0

    func increment() {
        live += 1
    }

    func decrement() {
        live -= 1
    }
}

final class Token {
    let counter: Counter

    init(_ counter: Counter) {
        self.counter = counter
        counter.increment()
    }

    deinit {
        counter.decrement()
    }
}

/// A generic component, to check that its name is a valid Flecs path.
struct Slot<T>: Component {
    var value: Int
}
