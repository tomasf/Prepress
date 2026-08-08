import Foundation
import Cadova

/// Records that a piece of geometry is a printable *component*: a self-contained part that
/// ``Cadova/Geometry3D/onPlatter(removingMaterials:separatingParts:)`` orients, multiplies and packs.
///
/// Only geometry explicitly declared with ``Cadova/Geometry3D/asComponent(name:upDirection:quantity:color:)``
/// (or the `Part` overload) carries this; the platter ignores everything else, including plain Cadova
/// ``Cadova/Geometry3D/inPart(_:)`` parts. A part with no declared print orientation can't be oriented
/// meaningfully, so it's left out rather than dropped onto the bed in an arbitrary rotation.
///
/// The up direction is stored together with the environment transform in effect where the component was
/// declared, so the packer can re-express it in whatever frame it reads — keeping orientation correct even
/// when an enclosing assembly is transformed afterwards. The quantity rides along in the same element.
struct ComponentData: ResultElement {
    struct Value: Sendable {
        var upDirection: Direction3D
        var transform: Transform3D
        var quantity: Int
        var slicerSettings: [SlicerSettingKey: String] = [:]

        /// Re-expresses the declared up direction in a reading frame. The direction was captured together
        /// with the transform in effect where it was declared, so re-projecting it relative to the reader
        /// keeps it correct under transforms applied in between (e.g. an enclosing assembly rotation).
        func resolvedUpDirection(in readingTransform: Transform3D) -> Direction3D {
            let t = transform.concatenated(with: readingTransform.inverse)
            return Direction3D(t.apply(to: upDirection.unitVector) - t.offset)
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
    let slicerSettings: [SlicerSettingKey: String]
}

public extension Geometry3D {
    /// Declares this geometry as a printable component for ``onPlatter(removingMaterials:separatingParts:)``,
    /// wrapped in a freshly named part.
    ///
    /// A component records which way is up when printed, how many copies to lay out, and an optional color.
    /// Only components are packed by ``onPlatter(removingMaterials:separatingParts:)``; plain Cadova
    /// ``Cadova/Geometry3D/inPart(_:)`` parts are left out.
    ///
    /// The declared up direction also informs Cadova's overhang compensation within the geometry, via
    /// ``Cadova/Geometry3D/definingNaturalUpDirection(_:)``.
    ///
    /// - Parameters:
    ///   - name: The name of the part, as it appears in the output file.
    ///   - upDirection: The direction, in this geometry's own coordinate system, that should point up when
    ///     the part is printed. Defaults to `.up`.
    ///   - quantity: The number of copies to lay out on the platter. Values below 1 are treated as 1.
    ///   - color: An optional default color for geometry in the part that doesn't specify its own material.
    ///   - slicerSettings: Per-object slicer settings written into the platter's `model_settings.config`
    ///     sidecar file (e.g. `[.sparseInfillDensity(15)]`). Recognized by Bambu Studio and its forks
    ///     (OrcaSlicer, etc.); ignored by other slicers. See ``onPlatter(removingMaterials:separatingParts:)``.
    /// - Returns: The geometry declared as a named printable component.
    func asComponent(
        name: String,
        upDirection: Direction3D = .up,
        quantity: Int = 1,
        color: Color? = nil,
        slicerSettings: [SlicerSetting] = []
    ) -> any Geometry3D {
        asComponent(
            Part(name, semantic: .solid, color: color),
            upDirection: upDirection,
            quantity: quantity,
            slicerSettings: slicerSettings
        )
    }

    /// Declares this geometry as a printable component for ``onPlatter(removingMaterials:separatingParts:)``,
    /// assigned to the given part.
    ///
    /// See ``asComponent(name:upDirection:quantity:color:slicerSettings:)``.
    ///
    /// - Parameters:
    ///   - part: The part to assign this component to.
    ///   - upDirection: The direction, in this geometry's own coordinate system, that should point up when
    ///     the part is printed. Defaults to `.up`.
    ///   - quantity: The number of copies to lay out on the platter. Values below 1 are treated as 1.
    ///   - slicerSettings: Per-object slicer settings written into a `model_settings.config` sidecar
    ///     embedded in the exported 3MF (e.g. `[.sparseInfillDensity(15)]`). Recognized by Bambu
    ///     Studio and its forks (OrcaSlicer, etc.); ignored by other slicers. Works whether or not the
    ///     component goes through ``onPlatter(removingMaterials:separatingParts:)`` — if it does, the
    ///     settings follow whatever final part(s) packing produces (e.g. numbered copies for `quantity` > 1).
    /// - Returns: The geometry declared as a printable component in the given part.
    func asComponent(
        _ part: Part,
        upDirection: Direction3D = .up,
        quantity: Int = 1,
        slicerSettings: [SlicerSetting] = []
    ) -> any Geometry3D {
        let slicerSettings = slicerSettings.byKey

        // `definingNaturalUpDirection` keeps Cadova's overhang compensation working inside the component;
        // the `ComponentData` result element is what the packer reads. The transform in effect here is
        // captured with the direction so the packer can resolve it in its own frame.
        var geometry = definingNaturalUpDirection(upDirection)
            .readingEnvironment(\.transform) { geometry, transform in
                geometry.withResult(ComponentData(.init(
                    upDirection: upDirection,
                    transform: transform,
                    quantity: Swift.max(1, quantity),
                    slicerSettings: slicerSettings
                )))
            }

        if !slicerSettings.isEmpty {
            geometry = geometry
                .modifyingResult(SlicerSettingsEntries.self) { $0.entries.append((part, slicerSettings)) }
                .withArchiveFinalizer { try SlicerSettingsEntries.writeConfigIfNeeded(to: $0) }
        }

        return geometry.inPart(part)
    }

    /// Lays out every printable component in this geometry on a single platter for 3D printing.
    ///
    /// Each component — declared with ``asComponent(name:upDirection:quantity:color:slicerSettings:)`` or
    /// its `Part` overload — is rotated so its declared up direction points to +Z, dropped so it rests on
    /// the `z = 0` plane, and then packed together with the others using the no-fit polygon nester.
    /// Components configured with a quantity contribute that many copies, each packed and emitted as its
    /// own part. Every component is re-emitted as its own named part, so they remain individually
    /// selectable and movable in a slicer. Geometry that isn't a component — including plain Cadova
    /// ``Cadova/Geometry3D/inPart(_:)`` parts — is discarded.
    ///
    /// If any component declared `slicerSettings`, this also embeds a `Metadata/model_settings.config`
    /// sidecar file into the exported 3MF, referencing each packed part by its assigned object id.
    /// Bambu Studio and its forks read this automatically, applying the settings without the user having
    /// to configure them by hand in the slicer.
    ///
    /// The packing margin and rotation count come from the environment
    /// (``Cadova/EnvironmentValues/packingMargin`` and ``Cadova/EnvironmentValues/packingRotationCount``);
    /// set them with ``Cadova/Geometry/withPackingMargin(_:)`` and
    /// ``Cadova/Geometry/withPackingRotationCount(_:)``.
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
            @Environment(\.packingMargin) var margin
            @Environment(\.packingRotationCount) var rotationCount
            let placed = await packComponents(
                of: base,
                using: evaluator,
                margin: margin,
                rotationCount: rotationCount,
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
    rotationCount: Int,
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
        guard let component = await evaluator.result(ComponentData.self, of: partGeometry).value else { continue }

        // The catalog exposes nested parts flattened at the top level, so each is packed on its own. Strip
        // any nested parts (of every semantic) from this part's geometry so they don't ride along.
        let geometry = PartSemantic.allCases.reduce(partGeometry) { $0.removingParts(ofType: $1) }

        // Orients one disconnected solid (or the whole body), drops it to z = 0, and applies the 2D packing
        // transform. Both the packing footprint and the final placed body come from this single function,
        // so they can never diverge — resolving the orientation in two places once let the footprint and
        // the placed body disagree, and parts overlapped.
        func orientedBody(componentIndex: Int?, placement: Transform2D) -> any Geometry3D {
            readEnvironment(\.transform) { transform in
                let oriented = geometry.rotated(from: component.resolvedUpDirection(in: transform), to: .up)
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
        let total = component.quantity * componentIndices.count
        var copy = 0
        for _ in 0 ..< component.quantity {
            for componentIndex in componentIndices {
                let copyPart = partForCopy(of: part, index: copy, total: total)
                entries.append(ComponentEntry(
                    part: copyPart,
                    packingBody: orientedBody(componentIndex: componentIndex, placement: .identity),
                    placedBody: { transform in
                        orientedBody(componentIndex: componentIndex, placement: transform)
                    },
                    slicerSettings: component.slicerSettings
                ))
                copy += 1
            }
        }
    }

    // Pack the real bodies (footprints need real geometry), then re-wrap each in its part.
    let packer = Packer(bodies: entries.map(\.packingBody), margin: margin, rotationCount: rotationCount, footprintDetail: 24)
    let transforms = await packer.placements(using: evaluator)

    return zip(entries, transforms).map { entry, transform -> any Geometry3D in
        let placed = entry.placedBody(transform)

        // removingMaterials emits into a freshly named, material-less part rather than `entry.part`. The
        // settings re-declaration below must key off whichever `Part` instance actually ends up in the
        // output — asComponent's own declaration (against the pre-packing part) won't resolve to a real
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
