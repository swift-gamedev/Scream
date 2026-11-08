// Turns Flecs' C names into Swift identifiers.

let swiftKeywords: Set<String> = [
    "default", "repeat", "static", "class", "struct", "enum", "func", "var", "let", "return", "true",
    "false", "nil", "self", "super", "import", "where", "as", "is", "in", "for", "while", "if", "else",
    "switch", "case", "break", "continue", "operator", "protocol", "extension", "init", "deinit",
    "subscript", "throws", "try", "catch", "do", "guard", "defer", "public", "private", "internal",
    "fileprivate", "open", "inout", "any", "some", "Type", "Self",
]

/// Swift names for the C enum types that the mechanical rule gets wrong.
let enumTypeNames: [String: String] = [
    "ecs_inout_kind_t": "InOutKind",
    "ecs_oper_kind_t": "OperatorKind",
    "ecs_http_method_t": "HTTPMethod",
    "ecs_meta_op_kind_t": "MetaOperationKind",
]

/// `ecs_query_cache_kind_t` becomes `QueryCacheKind`.
func swiftEnumName(_ cName: String) -> String {
    if let name = enumTypeNames[cName] {
        return name
    }
    var rest = cName
    if rest.hasPrefix("ecs_") {
        rest.removeFirst(4)
    }
    if rest.hasSuffix("_t") {
        rest.removeLast(2)
    }
    return rest.split(separator: "_").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
}

/// The prefix every constant of an enum shares, cut back to a word boundary: the letter after it
/// is a capital in every name, so `EcsQueryCacheAll` and `EcsQueryCacheAuto` give `EcsQueryCache`,
/// and `EcsInOut` next to `EcsIn` and `EcsOut` gives `Ecs`.
func commonPrefix(of names: [String]) -> String {
    guard var prefix = names.first else { return "" }
    for name in names.dropFirst() {
        while !name.hasPrefix(prefix) {
            prefix.removeLast()
        }
    }
    func isBoundary(_ prefix: String) -> Bool {
        names.allSatisfy { name in
            guard name.count > prefix.count else { return false }
            return name[name.index(name.startIndex, offsetBy: prefix.count)].isUppercase
        }
    }
    while !prefix.isEmpty, !isBoundary(prefix) {
        prefix.removeLast()
    }
    return prefix
}

/// `EcsInOutDefault` with prefix `Ecs` becomes `inOutDefault`; keywords get backticks.
func swiftCaseName(_ cName: String, prefix: String) -> String {
    let rest = cName.hasPrefix(prefix) ? String(cName.dropFirst(prefix.count)) : cName
    return escape(lowerCamel(rest))
}

/// `EcsChildOf` becomes `childOf`.
func swiftBuiltinName(_ cName: String) -> String {
    escape(lowerCamel(String(cName.dropFirst("Ecs".count))))
}

/// Lowercases the leading capital, or a leading run of capitals except its last letter when a
/// lowercase letter follows: `ChildOf` is `childOf`, `ID` is `id`, `UPtr` is `uPtr`.
func lowerCamel(_ name: String) -> String {
    let characters = Array(name)
    var end = 0
    while end < characters.count, characters[end].isUppercase {
        end += 1
    }
    guard end > 0 else { return name }
    let lowered = end == characters.count ? end : max(1, end - 1)
    return String(characters[..<lowered]).lowercased() + String(characters[lowered...])
}

func escape(_ name: String) -> String {
    var name = name
    if let first = name.first, first.isNumber {
        name = "_" + name
    }
    return swiftKeywords.contains(name) ? "`\(name)`" : name
}

/// Formats a Doxygen paragraph as a `///` line, or a fallback naming the C symbol.
func docComment(_ text: String?, fallback: String, indent: String = "") -> String {
    let trimmed = (text ?? "").trimmingCharacters(in: .whitespaces)
    let body: String
    if trimmed.isEmpty {
        body = fallback
    } else {
        let sentence = trimmed.hasSuffix(".") ? trimmed : trimmed + "."
        body = sentence.prefix(1).uppercased() + sentence.dropFirst()
    }
    return "\(indent)/// \(body)\n"
}
