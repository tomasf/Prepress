import Foundation

/// A label saying what a ``Component`` is, which ``Cadova/Geometry3D/onPlatter(only:excluding:removingMaterials:)``
/// can select by when an assembly doesn't fit on one platter.
///
/// Tags are compared by name. Declare them as static constants, so that a misspelled tag fails to compile
/// rather than quietly selecting nothing:
///
/// ```swift
/// extension ComponentTag {
///     static let wheels = ComponentTag("Wheels")
///     static let flexible = ComponentTag("Flexible")
/// }
///
/// tire.inComponent(name: "Tire", tags: [.wheels, .flexible])
/// ```
public struct ComponentTag: Sendable, Hashable {
    /// The name that identifies this tag.
    public let name: String

    /// Creates a tag with the given name. Two tags with the same name are the same tag.
    public init(_ name: String) {
        self.name = name
    }
}

/// Which components a platter takes.
struct ComponentSelection: Sendable {
    /// The tags a component needs at least one of, or `nil` to take any component.
    let only: Set<ComponentTag>?
    /// The tags a component must have none of.
    let excluding: Set<ComponentTag>

    func includes(_ component: Component) -> Bool {
        if let only, only.isDisjoint(with: component.tags) { return false }
        return excluding.isDisjoint(with: component.tags)
    }

    /// What looks like a mistake about this selection, given every component in the assembly. A plate is
    /// expected to hold something and each named tag to mean something, and neither can be told apart
    /// from a correct selection once the file is written, since the result is merely a smaller plate.
    func problems(in components: [Component]) -> [String] {
        guard only != nil || !excluding.isEmpty else { return [] }
        var problems: [String] = []

        let knownTags = components.reduce(into: Set<ComponentTag>()) { $0.formUnion($1.tags) }
        let unknownTags = (only ?? []).union(excluding).subtracting(knownTags)
        if !unknownTags.isEmpty {
            let names = unknownTags.map(\.name).sorted().joined(separator: ", ")
            problems.append("onPlatter selects by tags no component has: \(names)")
        }
        if !components.contains(where: includes) {
            problems.append("onPlatter's selection matched no components, leaving the platter empty")
        }
        return problems
    }

    /// Reports ``problems(in:)`` on standard error.
    func reportProblems(in components: [Component]) {
        for problem in problems(in: components) {
            FileHandle.standardError.write(Data("Prepress warning: \(problem)\n".utf8))
        }
    }
}
