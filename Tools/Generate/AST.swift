import Foundation

// Reads flecs.h through clang's JSON AST dump. Flecs ships no machine-readable description of its
// API, so the generator parses the umbrella header exactly as the Swift importer does: as C, with
// the configuration macros from CFlecs.h.

/// The parts of a clang `-ast-dump=json` node the generator reads.
struct Node: Decodable {
    var kind: String?
    var name: String?
    var loc: Location?
    var type: TypeReference?
    var storageClass: String?
    var value: String?
    var text: String?
    var inner: [Node]?

    struct Location: Decodable {
        var line: Int?
        var file: String?
        var expansionLoc: Point?
        var spellingLoc: Point?

        struct Point: Decodable {
            var line: Int?
            var file: String?
        }

        /// The file this location is in, if the dump names one here (it only does when it changes).
        var anyFile: String? {
            file ?? expansionLoc?.file ?? spellingLoc?.file
        }

        var anyLine: Int? {
            line ?? expansionLoc?.line ?? spellingLoc?.line
        }
    }

    struct TypeReference: Decodable {
        var qualType: String
    }

    /// The first paragraph of the Doxygen comment attached to this declaration, as one line.
    var documentation: String? {
        guard let comment = inner?.first(where: { $0.kind == "FullComment" }),
            let paragraph = comment.inner?.first(where: { $0.kind == "ParagraphComment" })
        else { return nil }
        let text = (paragraph.inner ?? [])
            .compactMap { $0.kind == "TextComment" ? $0.text : nil }
            .joined(separator: " ")
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
        return text.isEmpty ? nil : text
    }
}

/// What the generator takes from the header.
struct API {
    var enums: [Enum]
    var builtins: [Builtin]
    var functions: [Function]
    /// `@defgroup` titles by line, for the coverage page.
    var groups: [(line: Int, title: String)]

    struct Enum {
        var cName: String
        var documentation: String?
        var line: Int
        var constants: [Constant]

        struct Constant {
            var cName: String
            var value: Int
            var documentation: String?
        }
    }

    /// An `extern const ecs_entity_t Ecs...` declaration: a builtin entity, tag or component id.
    struct Builtin {
        var cName: String
        var documentation: String?
        var line: Int
    }

    struct Function {
        var name: String
        var line: Int
    }

    /// Runs clang over `header` and extracts the declarations that `header` itself makes.
    static func load(header: URL, clang: URL) throws -> API {
        let dump = try runClang(clang, header: header)
        let root = try JSONDecoder().decode(Node.self, from: dump)
        let headerName = header.lastPathComponent
        let flecsHeader = "flecs.h"

        var enums: [Enum] = []
        var builtins: [Builtin] = []
        var functions: [Function] = []
        var currentFile = ""
        var pendingAnonymousEnum: Enum?

        for node in root.inner ?? [] {
            if let file = node.loc?.anyFile {
                currentFile = file
            }
            let inFlecs = currentFile.hasSuffix(flecsHeader) || currentFile.hasSuffix(headerName)
            guard inFlecs, let line = node.loc?.anyLine else { continue }

            switch node.kind ?? "" {
            case "EnumDecl":
                let constants = try enumConstants(node)
                guard !constants.isEmpty else { continue }
                let enumeration = Enum(
                    cName: node.name ?? "", documentation: node.documentation, line: line, constants: constants)
                if node.name == nil {
                    // typedef enum { ... } name_t; the typedef comes next and carries the name.
                    pendingAnonymousEnum = enumeration
                } else {
                    enums.append(enumeration)
                }
            case "TypedefDecl":
                if var pending = pendingAnonymousEnum, let name = node.name {
                    pending.cName = name
                    pending.documentation = pending.documentation ?? node.documentation
                    enums.append(pending)
                }
                pendingAnonymousEnum = nil
            case "VarDecl":
                guard node.storageClass == "extern", let name = node.name, name.hasPrefix("Ecs"),
                    let type = node.type?.qualType, type == "const ecs_entity_t" || type == "const ecs_id_t"
                else { continue }
                builtins.append(Builtin(cName: name, documentation: node.documentation, line: line))
            case "FunctionDecl":
                guard node.storageClass != "static", let name = node.name, name.hasPrefix("ecs_") else { continue }
                functions.append(Function(name: name, line: line))
            default:
                pendingAnonymousEnum = nil
            }
        }

        let groups = try defgroups(in: header)
        return API(enums: enums, builtins: builtins, functions: functions, groups: groups)
    }

    /// Enum constants with their values: explicit ones from the initializer, the rest counting up.
    private static func enumConstants(_ enumeration: Node) throws -> [Enum.Constant] {
        var constants: [Enum.Constant] = []
        var next = 0
        for constant in enumeration.inner ?? [] where constant.kind == "EnumConstantDecl" {
            guard let name = constant.name else { continue }
            if let expression = constant.inner?.first(where: { $0.kind == "ConstantExpr" }) {
                guard let text = expression.value, let value = Int(text) else {
                    throw GenerateError("\(name): cannot read the initializer of the enum constant")
                }
                next = value
            }
            constants.append(Enum.Constant(cName: name, value: next, documentation: constant.documentation))
            next += 1
        }
        return constants
    }

    /// Doxygen `@defgroup id Title` lines in the header that `header` includes, by line number.
    private static func defgroups(in header: URL) throws -> [(line: Int, title: String)] {
        let flecsHeader = header.deletingLastPathComponent().appending(path: "../flecs/distr/flecs.h")
        let text = try String(contentsOf: flecsHeader, encoding: .utf8)
        var groups: [(line: Int, title: String)] = []
        for (index, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            guard let range = line.range(of: "@defgroup ") else { continue }
            let rest = line[range.upperBound...].split(separator: " ", maxSplits: 1)
            guard rest.count == 2 else { continue }
            var title = rest[1].trimmingCharacters(in: .whitespaces)
            if title.hasSuffix(".") {
                title.removeLast()
            }
            groups.append((index + 1, title))
        }
        return groups
    }

    private static func runClang(_ clang: URL, header: URL) throws -> Data {
        let process = Process()
        process.executableURL = clang
        process.arguments = [
            "-x", "c", "-std=gnu11", "-fsyntax-only", "-Wno-everything",
            "-Xclang", "-ast-dump=json", header.path(percentEncoded: false),
        ]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.standardError
        try process.run()
        // Read before waiting, or a full pipe stalls clang and the wait never returns.
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw GenerateError("clang exited with status \(process.terminationStatus)")
        }
        return data
    }
}

/// Finds clang: `SCREAM_CLANG`, then `PATH`, then the one beside `swift` in the toolchain.
func findClang() throws -> URL {
    let environment = ProcessInfo.processInfo.environment
    if let path = environment["SCREAM_CLANG"] {
        return URL(filePath: path)
    }
    let searchPath = (environment["PATH"] ?? "").split(separator: ":").map(String.init)
    for directory in searchPath {
        let candidate = URL(filePath: directory).appending(path: "clang")
        if FileManager.default.isExecutableFile(atPath: candidate.path(percentEncoded: false)) {
            return candidate
        }
    }
    for directory in searchPath {
        let swift = URL(filePath: directory).appending(path: "swift")
        guard FileManager.default.isExecutableFile(atPath: swift.path(percentEncoded: false)) else { continue }
        let candidate = swift.resolvingSymlinksInPath().deletingLastPathComponent().appending(path: "clang")
        if FileManager.default.isExecutableFile(atPath: candidate.path(percentEncoded: false)) {
            return candidate
        }
    }
    throw GenerateError("clang not found; set SCREAM_CLANG to the clang in your Swift toolchain")
}

struct GenerateError: Error, CustomStringConvertible {
    var description: String

    init(_ description: String) {
        self.description = description
    }
}
