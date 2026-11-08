import CFlecs
import CFlecsShims

/// Flecs' log: the warnings and errors it prints, and its trace output when enabled.
public enum Log {
    /// How serious a message is. Flecs counts down from debug detail to fatal.
    public enum Level: Int32, Sendable, Comparable {
        /// An error Flecs cannot continue from; the process aborts after logging it.
        case fatal = -4
        /// An error, such as an invalid query.
        case error = -3
        /// Something suspicious that Flecs recovered from.
        case warning = -2
        /// Normal progress, such as worlds and systems being created. Off by default.
        case trace = 0
        /// Debug detail. Off by default.
        case debug = 1
        /// More debug detail.
        case debug2 = 2
        /// Even more debug detail.
        case debug3 = 3

        /// Orders levels from fatal up to the most detailed debug level.
        public static func < (lhs: Level, rhs: Level) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    /// Receives one message. Called on whichever thread Flecs logs from, which can be a worker
    /// during a multi-threaded frame.
    public typealias Handler = @Sendable (Level, String) -> Void

    nonisolated(unsafe) private static var handler: Handler?

    /// Redirects Flecs' log to `handler`, or back to its own stderr output when nil.
    ///
    /// Call this before creating a ``World`` and from one thread; Flecs reads the handler without
    /// locking. The level filter from ``setLevel(_:)`` applies before the handler is called.
    public static func setHandler(_ handler: Handler?) {
        Self.handler = handler
        screamSetLogHandler(handler == nil ? nil : forwardToHandler)
    }

    /// Shows messages at `level` and more serious. Flecs' default shows warnings and errors.
    public static func setLevel(_ level: Level) {
        _ = ecs_log_set_level(level.rawValue)
    }

    /// Turns the color codes in Flecs' own stderr output on or off.
    public static func setColors(_ enabled: Bool) {
        _ = ecs_log_enable_colors(enabled)
    }

    fileprivate static func dispatch(_ level: Int32, _ message: String) {
        guard let handler else { return }
        // Flecs uses one level per debug depth, and anything above the ones named is more detail.
        handler(Level(rawValue: level) ?? (level > 0 ? .debug3 : .trace), message)
    }
}

private let forwardToHandler: ScreamLogHandler = { level, _, _, message in
    Log.dispatch(level, message.map { String(cString: $0) } ?? "")
}
