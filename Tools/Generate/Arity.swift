// The fixed-arity query, system and observer overloads.
//
// Swift's optimizer does not specialize parameter packs: a row loop written with `repeat each`
// runs about 70 times slower than the same loop over ordinary generic parameters (measured at
// 102 ns against 1.4 ns per row). So every arity from 1 to maxArity gets its own `TermsN` type and
// its own overloads, written here rather than by hand.

let maxArity = 8

private let letters = ["A", "B", "C", "D", "E", "F", "G", "H"]
private let lineWidth = 120

func emitArity() -> String {
    var out = generatedHeader
    out += """
        //
        // Why this file exists: Swift does not specialize parameter packs, so a row loop written with
        // `repeat each` costs about 100 ns per entity against 1.4 ns for ordinary generics. Each arity
        // therefore gets its own TermsN type and overloads.

        import CFlecs

        """
    for arity in 1...maxArity {
        out += "\n" + emitTerms(arity)
    }
    out += "\nextension World {\n"
    for arity in 1...maxArity {
        if arity > 1 {
            out += "\n"
        }
        out += emitWorldOverloads(arity)
    }
    out += "}\n"
    return out
}

/// `head(args)` on one line when it fits, otherwise the arguments filled onto indented lines.
private func call(_ head: String, _ arguments: [String], indent: Int, trailing: String = "") -> String {
    let pad = String(repeating: " ", count: indent)
    let single = "\(pad)\(head)(\(arguments.joined(separator: ", ")))\(trailing)"
    if single.count <= lineWidth {
        return single + "\n"
    }
    return "\(pad)\(head)(\n" + fill(arguments, indent: indent + 4) + "\(pad))\(trailing)\n"
}

/// `items` separated by `, `, filled onto as few lines of `lineWidth` as possible.
private func fill(_ items: [String], indent: Int) -> String {
    let pad = String(repeating: " ", count: indent)
    var lines: [String] = []
    var current = ""
    for (index, item) in items.enumerated() {
        let piece = index == items.count - 1 ? item : item + ","
        if current.isEmpty {
            current = pad + piece
        } else if (current + " " + piece).count <= lineWidth {
            current += " " + piece
        } else {
            lines.append(current)
            current = pad + piece
        }
    }
    if !current.isEmpty {
        lines.append(current)
    }
    return lines.map { $0 + "\n" }.joined()
}

private struct Arity {
    let count: Int
    var names: [String] { Array(letters.prefix(count)) }
    /// `A: QueryTerm, B: QueryTerm`
    var generics: [String] { names.map { "\($0): QueryTerm" } }
    /// `Terms2<A, B>`
    var terms: String { "Terms\(count)<\(names.joined(separator: ", "))>" }
    /// `A.Access, B.Access`
    var accesses: [String] { names.map { "\($0).Access" } }
    /// `_ a: A.Type, _ b: B.Type`
    var typeParameters: [String] { names.map { "_ \($0.lowercased()): \($0).Type" } }
    /// `A.Value: Sendable, B.Value: Sendable`
    var sendable: [String] { names.map { "\($0).Value: Sendable" } }
    /// `A.access(a, row: row), B.access(b, row: row)`
    var accessCalls: [String] { names.map { "\($0).access(\($0.lowercased()), row: row)" } }
    var word: String {
        ["one", "two", "three", "four", "five", "six", "seven", "eight"][count - 1]
    }
}

/// A public typealias for a closure type, laid out the way swift-format wants when it is long:
/// the type on its own line after `=`, and its parameters on further lines if still too long.
private func alias(_ name: String, prefix: String, parameters: [String]) -> String {
    let type = "\(prefix)(\(parameters.joined(separator: ", "))) -> Void"
    let single = "    public typealias \(name) = \(type)"
    if single.count <= lineWidth {
        return single + "\n"
    }
    let twoLines = "    public typealias \(name) =\n        \(type)"
    if twoLines.split(separator: "\n").allSatisfy({ $0.count <= lineWidth }) {
        return twoLines + "\n"
    }
    return "    public typealias \(name) =\n        \(prefix)(\n" + fill(parameters, indent: 12) + "        ) -> Void\n"
}

private func emitTerms(_ count: Int) -> String {
    let arity = Arity(count: count)
    let fields = arity.names.enumerated().map { index, name in
        "        let \(name.lowercased()) = Field<\(name)>(iteration: iteration, index: \(index))\n"
    }.joined()
    let ids = arity.names.map { "(Id(rawValue: stage.componentId(\($0).Value.self)), \($0).inOut)" }
    let header = "public struct Terms\(count)<\(arity.generics.joined(separator: ", "))>: QueryTerms {"
    let wrappedHeader =
        header.count <= lineWidth
        ? header
        : "public struct Terms\(count)<\n" + fill(arity.generics, indent: 4) + ">: QueryTerms {"
    let withEntity = ["Entity"] + arity.accesses
    let withIteration = ["Iteration", "Entity"] + arity.accesses
    var out = """
        /// The terms of a query with \(arity.word) component\(count == 1 ? "" : "s").
        \(wrappedHeader)
            /// A closure over the accessors.
        \(alias("Each", prefix: "", parameters: arity.accesses))    /// A closure over the entity and the accessors.
        \(alias("EachEntity", prefix: "", parameters: withEntity))    /// A closure over the iteration, the entity and the accessors.
        \(alias("EachIteration", prefix: "", parameters: withIteration))    /// ``Each`` for a multi-threaded system, which runs it on several threads at once.
        \(alias("SendableEach", prefix: "@Sendable ", parameters: arity.accesses))    /// ``EachIteration`` for a multi-threaded system.
        \(alias("SendableEachIteration", prefix: "@Sendable ", parameters: withIteration))
            /// The terms' ids and access modes in `stage`'s world.
            public static func terms(in stage: Stage) -> [(id: Id, inOut: InOutKind)] {

        """
    if count == 1 {
        out += "        [\(ids[0])]\n"
    } else {
        out += "        [\n" + ids.map { "            \($0),\n" }.joined() + "        ]\n"
    }
    out += "    }\n"
    let loops: [(doc: String, name: String, closure: String, arguments: [String])] = [
        ("Calls `body` for every row of `iteration`.", "forEach", "Each", arity.accessCalls),
        (
            "Calls `body` for every row of `iteration` with its entity.", "forEachEntity", "EachEntity",
            ["iteration.entity(at: row)"] + arity.accessCalls
        ),
        (
            "Calls `body` for every row of `iteration` with the iteration and its entity.", "forEachIteration",
            "EachIteration", ["iteration", "iteration.entity(at: row)"] + arity.accessCalls
        ),
    ]
    for loop in loops {
        out += """

                /// \(loop.doc)
                @inlinable
                public static func \(loop.name)(_ iteration: Iteration, body: \(loop.closure)) {
            \(fields)        for row in 0..<iteration.count {

            """
        out += call("body", loop.arguments, indent: 12)
        out += "        }\n    }\n"
    }
    out += "}\n"
    return out
}

/// `public func name<generics>(` with the generics wrapped when long.
private func signature(_ name: String, _ arity: Arity) -> String {
    let single = "    public func \(name)<\(arity.generics.joined(separator: ", "))>("
    if single.count <= lineWidth {
        return single + "\n"
    }
    return "    public func \(name)<\n" + fill(arity.generics, indent: 8) + "    >(\n"
}

private func emitWorldOverloads(_ count: Int) -> String {
    let arity = Arity(count: count)
    let more = count == 1 ? "" : " with \(arity.word) components"
    let see = count == 1 ? "" : " See the one-component overload for the parameters."
    let queryDoc =
        count == 1
        ? """
            /// Creates a query for entities that have every term's component, narrowed by `filter`.
            ///
            /// - Parameters:
            ///   - a: ``In``, ``InOut`` or ``Out`` of the component the closure needs.
            ///   - filter: Tags, components and pairs the entities must have or must not have.
            /// - Returns: The query, which stays valid until it or the world goes out of scope.

        """
        : "    /// Creates a query\(more).\(see)\n"
    let systemDoc =
        count == 1
        ? """
            /// Creates a system: a query whose closure runs once per matched entity every frame, in
            /// `phase`.
            ///
            /// ```swift
            /// world.system(InOut<Position>.self, In<Velocity>.self, name: "Move") { position, velocity in
            ///     position.x += velocity.x
            /// }
            /// ```
            ///
            /// Systems in the same phase run in the order they were created, unless Flecs reorders them
            /// by what they read and write. The closure runs on the thread calling
            /// ``progress(deltaTime:)``; see `parallelSystem` for the multi-threaded kind. Overloads take
            /// a closure that also receives the ``Entity``, or the ``Iteration`` (for the stage and the
            /// time step) and the entity, and the same again for two to eight components.
            ///
            /// - Parameters:
            ///   - a: ``In``, ``InOut`` or ``Out`` of the component the closure needs.
            ///   - name: The system's entity name, shown in the Flecs Explorer and in logs.
            ///   - phase: When in the frame the system runs; one of Flecs' phases such as
            ///     ``Entity/onUpdate``, or a custom one from ``phase(_:after:)``.
            ///   - filter: Tags, components and pairs the entities must have or must not have.
            ///   - body: Called per entity with the accessors for each term.
            /// - Returns: The system's entity, for ``run(_:deltaTime:)``, ``setInterval(_:seconds:)`` and
            ///   ``WorldAccess/setEnabled(_:_:)``.

        """
        : "    /// Creates a system\(more).\(see)\n"
    let parallelDoc =
        count == 1
        ? """
            /// Creates a system that Flecs splits across the threads from ``setThreads(_:)``.
            ///
            /// The closure must be `@Sendable` and the components `Sendable`, since it runs on several
            /// threads at once, each over its own slice of the matched entities. Where there are no
            /// threads (Wasm, or without ``setThreads(_:)``) it runs like a plain system. See `system`
            /// for the parameters.

        """
        : "    /// Creates a multi-threaded system\(more).\(see)\n"
    let observerDoc =
        count == 1
        ? """
            /// Creates an observer: a closure that runs when one of `events` happens to an entity matching
            /// the terms and filter.
            ///
            /// ```swift
            /// world.observer(In<Position>.self, events: [.onSet]) { iteration, entity, position in
            ///     print("\\(entity) moved to \\(position.value)")
            /// }
            /// ```
            ///
            /// The events are ``Entity/onAdd``, ``Entity/onSet`` and ``Entity/onRemove``. For `onRemove`
            /// the closure still sees the values, just before they go. For `onAdd` the value is not set
            /// yet and must not be read: the memory is not initialized until the set that follows, as in
            /// Flecs itself for a component without a constructor. Inside a frame the observer runs when
            /// the change is merged; outside one, immediately.
            ///
            /// - Parameters:
            ///   - a: ``In``, ``InOut`` or ``Out`` of the component the closure needs. The event has to
            ///     involve it, or a filter term.
            ///   - events: Which changes to observe.
            ///   - name: The observer's entity name.
            ///   - filter: Tags, components and pairs the entities must have or must not have.
            ///   - yieldExisting: Whether to call the closure right away for entities that already match,
            ///     as if they had just been added.
            ///   - body: Called per entity with the ``Iteration`` (whose ``Iteration/event`` says which
            ///     event fired), the entity, and the accessors for each term.
            /// - Returns: The observer's entity.

        """
        : "    /// Creates an observer\(more).\(see)\n"

    var out = queryDoc
    out += signature("query", arity)
    out += fill(arity.typeParameters + ["filter: [QueryFilter] = []"], indent: 8)
    out += "    ) -> Query<\(arity.terms)> {\n        makeQuery(filter: filter)\n    }\n"

    let systemVariants: [(doc: String, alias: String, call: String)] = [
        (systemDoc, "Each", "forEach"),
        ("    /// Creates a system\(more) whose closure also receives the entity.\n", "EachEntity", "forEachEntity"),
        (
            "    /// Creates a system\(more) whose closure also receives the ``Iteration`` and the entity.\n",
            "EachIteration", "forEachIteration"
        ),
    ]
    for variant in systemVariants {
        out += "\n" + variant.doc
        out += "    @inlinable\n    @discardableResult\n"
        out += signature("system", arity)
        out += fill(
            arity.typeParameters + [
                "name: String? = nil", "phase: Entity = .onUpdate", "filter: [QueryFilter] = []",
                "each body: @escaping \(arity.terms).\(variant.alias)",
            ], indent: 8)
        out += "    ) -> Entity {\n"
        out += call(
            "makeSystem", ["\(arity.terms).self", "name: name", "phase: phase", "filter: filter", "parallel: false"],
            indent: 8, trailing: " {")
        out += "            \(arity.terms).\(variant.call)($0, body: body)\n        }\n    }\n"
    }

    let parallelVariants: [(doc: String, alias: String, call: String)] = [
        (parallelDoc, "SendableEach", "forEach"),
        (
            "    /// Creates a multi-threaded system\(more) whose closure also receives the ``Iteration`` and\n"
                + "    /// the entity.\n",
            "SendableEachIteration", "forEachIteration"
        ),
    ]
    for variant in parallelVariants {
        out += "\n" + variant.doc
        out += "    @inlinable\n    @discardableResult\n"
        out += signature("parallelSystem", arity)
        out += fill(
            arity.typeParameters + [
                "name: String? = nil", "phase: Entity = .onUpdate", "filter: [QueryFilter] = []",
                "each body: @escaping \(arity.terms).\(variant.alias)",
            ], indent: 8)
        let whereClause = "    ) -> Entity where \(arity.sendable.joined(separator: ", ")) {"
        if whereClause.count <= lineWidth {
            out += whereClause + "\n"
        } else {
            out += "    ) -> Entity\n    where\n" + fill(arity.sendable, indent: 8) + "    {\n"
        }
        out += call(
            "makeSystem", ["\(arity.terms).self", "name: name", "phase: phase", "filter: filter", "parallel: true"],
            indent: 8, trailing: " {")
        out += "            \(arity.terms).\(variant.call)($0, body: body)\n        }\n    }\n"
    }

    out += "\n" + observerDoc
    out += "    @inlinable\n    @discardableResult\n"
    out += signature("observer", arity)
    out += fill(
        arity.typeParameters + [
            "events: [Entity]", "name: String? = nil", "filter: [QueryFilter] = []", "yieldExisting: Bool = false",
            "each body: @escaping \(arity.terms).EachIteration",
        ], indent: 8)
    out += "    ) -> Entity {\n"
    out += call(
        "makeObserver",
        ["\(arity.terms).self", "events: events", "name: name", "filter: filter", "yieldExisting: yieldExisting"],
        indent: 8, trailing: " {")
    out += "            \(arity.terms).forEachIteration($0, body: body)\n        }\n    }\n"
    return out
}
