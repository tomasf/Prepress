import Foundation
@_spi(ArchiveFinalizer) import Cadova

/// A printable component: a self-contained piece of a model, together with what's needed to print it —
/// which way is up, how many copies to lay out, and any per-object slicer settings.
///
/// Create a component once and mark geometry with it, the way Cadova's ``Cadova/Part`` works:
///
/// ```swift
/// let bracket = Component("Bracket", upDirection: .right, quantity: 4)
///
/// Box(10)
///     .inComponent(bracket)
/// ```
///
/// A component owns the ``Cadova/Part`` its geometry is emitted into and creates it privately, so each
/// component you create is a distinct part even when two share a name, and no two components can be
/// handed the same part — which would silently merge them into one object in the output. Marking
/// several pieces of geometry with the *same* component instance does merge them, deliberately: that's
/// how one component is built out of several bodies.
public struct Component: Sendable {
    /// The part this component's geometry is emitted into.
    ///
    /// Read-only on purpose: it's here so a component can be used with Cadova APIs that take a
    /// ``Cadova/Part`` (``Cadova/Geometry/detachingPart(_:_:)``, looking geometry up in the part
    /// catalog, and so on). There's deliberately no way to go the other way and build a component
    /// around an existing part, which is what keeps two components from ever sharing one.
    public let part: Part

    /// Already collapsed to one value per key, per slicer flavor, in declaration order.
    internal let slicerSettings: ResolvedSlicerSettings

    /// The direction, in the geometry's own coordinate system, that points up when the component is printed.
    public let upDirection: Direction3D

    /// The number of copies to lay out on the platter. Always at least 1.
    public let quantity: Int

    /// The name of the component, as it appears in the output file.
    public var name: String { part.name }

    private init(part: Part, upDirection: Direction3D, quantity: Int, slicerSettings: [SlicerSetting]) {
        self.part = part
        self.upDirection = upDirection
        self.quantity = Swift.max(1, quantity)
        self.slicerSettings = slicerSettings.resolved
    }

    /// Creates a component with a plain color as its default material.
    ///
    /// - Parameters:
    ///   - name: The name of the component, as it appears in the output file.
    ///   - upDirection: The direction, in the geometry's own coordinate system, that should point up when
    ///     the component is printed. Defaults to `.up`.
    ///   - quantity: The number of copies to lay out on the platter. Values below 1 are treated as 1.
    ///   - color: An optional default color for geometry that doesn't specify its own material.
    ///   - slicerSettings: Per-object slicer settings embedded in the exported 3MF (e.g.
    ///     `[.infillDensity(15)]`). Each setting is written in whichever of the two sidecar formats
    ///     support it, so the same file configures Bambu Studio and its forks (OrcaSlicer, Creality
    ///     Print, …) as well as PrusaSlicer and SuperSlicer.
    public init(
        _ name: String,
        upDirection: Direction3D = .up,
        quantity: Int = 1,
        color: Color? = nil,
        slicerSettings: [SlicerSetting] = []
    ) {
        self.init(
            part: Part(name, semantic: .solid, color: color),
            upDirection: upDirection,
            quantity: quantity,
            slicerSettings: slicerSettings
        )
    }

    /// Creates a component with a physically-based default material.
    ///
    /// See ``init(_:upDirection:quantity:color:slicerSettings:)``.
    public init(
        _ name: String,
        upDirection: Direction3D = .up,
        quantity: Int = 1,
        material: Material?,
        slicerSettings: [SlicerSetting] = []
    ) {
        self.init(
            part: Part(name, semantic: .solid, material: material),
            upDirection: upDirection,
            quantity: quantity,
            slicerSettings: slicerSettings
        )
    }
}

/// Records that a piece of geometry is a printable ``Component`` that
/// ``Cadova/Geometry3D/onPlatter(removingMaterials:separatingParts:)`` orients, multiplies and packs.
///
/// Only geometry explicitly declared with ``Cadova/Geometry3D/inComponent(_:)`` (or its `name:` variant)
/// carries this; the platter ignores everything else, including plain Cadova
/// ``Cadova/Geometry3D/inPart(_:)`` parts. A part with no declared print orientation can't be oriented
/// meaningfully, so it's left out rather than dropped onto the bed in an arbitrary rotation.
///
/// The component is stored together with the environment transform in effect where it was declared, so
/// the packer can re-express its up direction in whatever frame it reads — keeping orientation correct
/// even when an enclosing assembly is transformed afterwards.
struct ComponentData: ResultElement {
    struct Value: Sendable {
        var component: Component
        var transform: Transform3D

        /// Re-expresses the declared up direction in a reading frame. The direction was captured together
        /// with the transform in effect where it was declared, so re-projecting it relative to the reader
        /// keeps it correct under transforms applied in between (e.g. an enclosing assembly rotation).
        func resolvedUpDirection(in readingTransform: Transform3D) -> Direction3D {
            let t = transform.concatenated(with: readingTransform.inverse)
            return Direction3D(t.apply(to: component.upDirection.unitVector) - t.offset)
        }
    }

    var value: Value?

    init() { value = nil }
    init(_ value: Value) { self.value = value }
    /// Components don't meaningfully merge. The most recently declared one wins — and because a component
    /// applies its own declaration outermost, a part's own value takes precedence over any nested
    /// component's value that bubbled up into the same part.
    init(combining elements: [ComponentData]) { value = elements.compactMap(\.value).last }
}

/// Builds a distinct part for one copy of a multiplied component, numbering the name when there is
/// more than one so each copy stays individually selectable in a slicer.
private func partForCopy(of part: Part, index: Int, total: Int) -> Part {
    guard total > 1 else { return part }
    return Part("\(part.name) \(index + 1)", semantic: part.semantic, material: part.defaultMaterial)
}

private struct ComponentEntry {
    let part: Part
    let packingBody: any Geometry3D
    let placedBody: (Transform2D) -> any Geometry3D
    let slicerSettings: ResolvedSlicerSettings
}

public extension Geometry3D {
    /// Declares this geometry as the given printable component, for
    /// ``onPlatter(removingMaterials:separatingParts:)``.
    ///
    /// Only components are packed by ``onPlatter(removingMaterials:separatingParts:)``; plain Cadova
    /// ``Cadova/Geometry3D/inPart(_:)`` parts are left out. Marking several pieces of geometry with the
    /// same component merges them into one, the way Cadova's ``Cadova/Part`` does.
    ///
    /// The component's up direction also informs Cadova's overhang compensation within the geometry, via
    /// ``Cadova/Geometry3D/definingNaturalUpDirection(_:)``.
    ///
    /// Any ``Component/slicerSettings`` work whether or not the component goes through
    /// ``onPlatter(removingMaterials:separatingParts:)`` — if it does, the settings follow whatever final
    /// part(s) packing produces (e.g. numbered copies for a `quantity` above 1).
    ///
    /// - Parameter component: The component this geometry belongs to.
    /// - Returns: The geometry declared as that printable component.
    func inComponent(_ component: Component) -> any Geometry3D {
        // `definingNaturalUpDirection` keeps Cadova's overhang compensation working inside the component;
        // the `ComponentData` result element is what the packer reads. The transform in effect here is
        // captured with the component so the packer can resolve its up direction in its own frame.
        var geometry = definingNaturalUpDirection(component.upDirection)
            .readingEnvironment(\.transform) { geometry, transform in
                geometry.withResult(ComponentData(.init(component: component, transform: transform)))
            }

        if !component.slicerSettings.isEmpty {
            geometry = geometry
                .modifyingResult(SlicerSettingsEntries.self) {
                    $0.entries.append((component.part, component.slicerSettings))
                }
                .withArchiveFinalizer { try await SlicerSettingsEntries.writeConfigsIfNeeded(to: $0) }
        }

        return geometry.inPart(component.part)
    }

    /// Declares this geometry as a printable component, creating the component in place.
    ///
    /// Equivalent to building a ``Component`` and passing it to ``inComponent(_:)``, for the common case
    /// where the component is only used here. Create a ``Component`` yourself when several pieces of
    /// geometry need to belong to the same one.
    ///
    /// - Parameters:
    ///   - name: The name of the component, as it appears in the output file.
    ///   - upDirection: The direction, in this geometry's own coordinate system, that should point up when
    ///     the component is printed. Defaults to `.up`.
    ///   - quantity: The number of copies to lay out on the platter. Values below 1 are treated as 1.
    ///   - color: An optional default color for geometry that doesn't specify its own material.
    ///   - slicerSettings: Per-object slicer settings written into the platter's config sidecars
    ///     (e.g. `[.infillDensity(15)]`), for both Bambu Studio and PrusaSlicer and their forks. See
    ///     ``onPlatter(removingMaterials:separatingParts:)``.
    /// - Returns: The geometry declared as a named printable component.
    func inComponent(
        name: String,
        upDirection: Direction3D = .up,
        quantity: Int = 1,
        color: Color? = nil,
        slicerSettings: [SlicerSetting] = []
    ) -> any Geometry3D {
        inComponent(Component(
            name,
            upDirection: upDirection,
            quantity: quantity,
            color: color,
            slicerSettings: slicerSettings
        ))
    }

    /// Lays out every printable component in this geometry on a single platter for 3D printing.
    ///
    /// Each component — declared with ``inComponent(_:)`` or ``inComponent(name:upDirection:quantity:color:slicerSettings:)``
    /// — is rotated so its declared up direction points to +Z, dropped so it rests on
    /// the `z = 0` plane, and then packed together with the others using the no-fit polygon nester.
    /// Components configured with a quantity contribute that many copies, each packed and emitted as its
    /// own part. Every component is re-emitted as its own named part, so they remain individually
    /// selectable and movable in a slicer. Geometry that isn't a component — including plain Cadova
    /// ``Cadova/Geometry3D/inPart(_:)`` parts — is discarded.
    ///
    /// If any component declared `slicerSettings`, this also embeds two sidecar files into the
    /// exported 3MF — `Metadata/model_settings.config` and `Metadata/Slic3r_PE_model.config` —
    /// referencing each packed part by its assigned object id. Each slicer reads whichever one it
    /// knows and ignores the other, applying the settings without the user having to configure them
    /// by hand.
    ///
    /// The gap left between neighboring components comes from the environment
    /// (``Cadova/EnvironmentValues/componentSpacing``); set it with
    /// ``Cadova/Geometry/withComponentSpacing(_:)``.
    ///
    /// - Parameters:
    ///   - removingMaterials: When `true`, strips all colors and materials from the packed result — both
    ///     those applied within each component and the parts' default materials — so the platter prints
    ///     as a single uniform material. Defaults to `false`, preserving each component's materials.
    ///   - separatingParts: When `true` (the default), each component is split into its disconnected
    ///     solids and every solid is packed and placed individually (as its own part) — disconnected
    ///     solids are separate physical objects and pack tighter on their own. Set to `false` to keep a
    ///     component's solids together as one rigid unit (e.g. when their relative arrangement matters).
    /// - Returns: The components packed onto a platter, each preserved as its own part.
    func onPlatter(removingMaterials: Bool = false, separatingParts: Bool = true) -> any Geometry3D {
        evaluating { base, evaluator in
            @Environment(\.footprintMargin) var margin
            let placed = await packComponents(
                of: base,
                using: evaluator,
                margin: margin,
                separatingParts: separatingParts,
                removingMaterials: removingMaterials
            )
            for component in placed { component }
        }
    }
}

/// Reads each printable component, orients it, drops it to z = 0, packs everything, and returns the
/// placed bodies (each re-wrapped in its own part). Kept as a plain async function — not a geometry
/// builder — so it can use ordinary control flow (loops, `continue`) while gathering the components.
private func packComponents(
    of base: any Geometry3D,
    using evaluator: GeometryEvaluator,
    margin: Double,
    separatingParts: Bool,
    removingMaterials: Bool
) async -> [any Geometry3D] {
    let partGeometries = await evaluator.parts(of: base, ofType: .solid)
    let parts = partGeometries.keys.sorted { $0.name < $1.name } // stable layout order

    var entries: [ComponentEntry] = []
    for part in parts {
        let partGeometry = partGeometries[part]!
        // Only declared components participate. A component applies its own declaration outermost, so the
        // combined value (last wins) is this part's own — a nested component that bubbled up doesn't shadow
        // it. Parts with no component data (plain Cadova parts) are skipped rather than guessed at.
        guard let data = await evaluator.result(ComponentData.self, of: partGeometry).value else { continue }

        // The catalog exposes nested parts flattened at the top level, so each is packed on its own. Strip
        // any nested parts (of every semantic) from this part's geometry so they don't ride along.
        let geometry = PartSemantic.allCases.reduce(partGeometry) { $0.removingParts(ofType: $1) }

        // Orients one disconnected solid (or the whole body), drops it to z = 0, and applies the 2D packing
        // transform. Both the packing footprint and the final placed body come from this single function,
        // so they can never diverge — resolving the orientation in two places once let the footprint and
        // the placed body disagree, and parts overlapped.
        func orientedBody(componentIndex: Int?, placement: Transform2D) -> any Geometry3D {
            readEnvironment(\.transform) { transform in
                let oriented = geometry.rotated(from: data.resolvedUpDirection(in: transform), to: .up)
                let solid: any Geometry3D
                if let componentIndex {
                    solid = oriented.separated { components in components[componentIndex] }
                } else {
                    solid = oriented
                }
                solid
                    .aligned(at: .minZ)
                    .transformed(placement.transform3D)
            }
        }

        // The component count is orientation-independent, so read it from the plain geometry.
        let componentCount = separatingParts ? await evaluator.components(of: geometry).count : 1
        // Drop each solid to z = 0, skipping any that are empty (an empty component has no footprint to
        // pack and would otherwise produce an empty part).
        var componentIndices: [Int?] = []
        for solidIndex in 0 ..< Swift.max(componentCount, 1) {
            let componentIndex: Int? = separatingParts ? solidIndex : nil
            if await evaluator.isEmpty(orientedBody(componentIndex: componentIndex, placement: .identity)) { continue }
            componentIndices.append(componentIndex)
        }
        let total = data.component.quantity * componentIndices.count
        var copy = 0
        for _ in 0 ..< data.component.quantity {
            for componentIndex in componentIndices {
                let copyPart = partForCopy(of: part, index: copy, total: total)
                entries.append(ComponentEntry(
                    part: copyPart,
                    packingBody: orientedBody(componentIndex: componentIndex, placement: .identity),
                    placedBody: { transform in
                        orientedBody(componentIndex: componentIndex, placement: transform)
                    },
                    slicerSettings: data.component.slicerSettings
                ))
                copy += 1
            }
        }
    }

    // Pack the real bodies (footprints need real geometry), then re-wrap each in its part.
    let packer = Packer(bodies: entries.map(\.packingBody), margin: margin, footprintDetail: 24)
    let transforms = await packer.placements(using: evaluator)

    return zip(entries, transforms).map { entry, transform -> any Geometry3D in
        let placed = entry.placedBody(transform)

        // removingMaterials emits into a freshly named, material-less part rather than `entry.part`. The
        // settings re-declaration below must key off whichever `Part` instance actually ends up in the
        // output — inComponent's own declaration (against the pre-packing part) won't resolve to a real
        // object id once packing has renamed or copied it, so it's this final identity that matters.
        let outputPart: Part
        let result: any Geometry3D
        if removingMaterials {
            outputPart = Part(entry.part.name, semantic: entry.part.semantic, material: nil)
            result = placed.withoutMaterials().inPart(outputPart)
        } else {
            outputPart = entry.part
            result = placed.inPart(outputPart)
        }

        let settings = entry.slicerSettings
        guard !settings.isEmpty else { return result }
        return result.modifyingResult(SlicerSettingsEntries.self) {
            $0.entries.append((outputPart, settings))
        }
    }
}
