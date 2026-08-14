import Foundation
@_spi(ArchiveFinalizer) import Cadova

/// A printable component: one piece of a model that's printed on its own, together with what's needed
/// to print it — how many copies to lay out and any per-object slicer settings.
///
/// A component is an identity you attach to geometry, the way Cadova's ``Cadova/Part`` works:
///
/// ```swift
/// let bracket = Component("Bracket", platter: .init(quantity: 4))
///
/// Box(10)
///     .inComponent(bracket, upDirection: .right)
/// ```
///
/// Which way is up is deliberately *not* part of the component. It belongs to each
/// ``Cadova/Geometry3D/inComponent(_:upDirection:)`` declaration, because it describes how that
/// particular body sits in the model rather than what the part is. That's what lets one component mark
/// several bodies scattered through an assembly at different orientations, with each stood up
/// correctly on the platter.
///
/// Each declaration is laid out as its own piece. Two components that share a name are still separate,
/// and there's deliberately no way to build a component around an existing ``Cadova/Part``, which is
/// what keeps two components from ever colliding in the output.
public struct Component: Sendable {
    /// Distinguishes this component from every other, including ones sharing its name.
    internal let id = UUID()

    /// The name of the component, as it appears in the output file.
    public let name: String

    /// The default material for geometry in this component that doesn't specify its own.
    internal let material: Material?

    /// The parts of this component's configuration that only apply once it's laid out on a platter.
    public let platter: PlatterOptions

    /// Already collapsed to one value per key, per slicer flavor, in declaration order.
    internal let slicerSettings: ResolvedSlicerSettings

    private init(name: String, material: Material?, platter: PlatterOptions, slicerSettings: [SlicerSetting]) {
        self.name = name
        self.material = material
        self.platter = platter
        self.slicerSettings = slicerSettings.resolved
    }

    /// Creates a component with a plain color as its default material.
    ///
    /// - Parameters:
    ///   - name: The name of the component, as it appears in the output file.
    ///   - platter: Options that only apply once the component is laid out on a platter, such as
    ///     how many copies to make. See ``PlatterOptions``.
    ///   - color: An optional default color for geometry that doesn't specify its own material.
    ///   - slicerSettings: Per-object slicer settings embedded in the exported 3MF (e.g.
    ///     `[.infillDensity(15)]`). Each setting is written in whichever of the two sidecar formats
    ///     support it, so the same file configures Bambu Studio and its forks (OrcaSlicer, Creality
    ///     Print, …) as well as PrusaSlicer and SuperSlicer.
    public init(
        _ name: String,
        platter: PlatterOptions = .default,
        color: Color? = nil,
        slicerSettings: [SlicerSetting] = []
    ) {
        self.init(
            name: name,
            material: color.map { Material.plain($0) },
            platter: platter,
            slicerSettings: slicerSettings
        )
    }

    /// Creates a part for one declaration of this component.
    ///
    /// ``Cadova/Geometry3D/inComponent(_:upDirection:part:)`` normally makes this part itself, and
    /// keeping it private is what stops two declarations from sharing one. Make it yourself only when
    /// something else needs the same ``Cadova/Part`` value — most often
    /// ``Cadova/Geometry/detachingPart(_:_:)``, to pull this piece back out of an assembly.
    ///
    /// - Important: A part made here belongs to exactly one declaration. Reusing it across several
    ///   merges them back into one, and only one of their orientations can survive — which is the
    ///   problem per-declaration parts exist to avoid. In an assembly that repeats a component, make
    ///   one per repetition (an instance property of whatever is repeated, not a static).
    public func makePart() -> Part {
        Part(name, semantic: .solid, material: material)
    }

    /// Creates a component with a physically-based default material.
    ///
    /// See ``init(_:platter:color:slicerSettings:)``.
    public init(
        _ name: String,
        platter: PlatterOptions = .default,
        material: Material?,
        slicerSettings: [SlicerSetting] = []
    ) {
        self.init(name: name, material: material, platter: platter, slicerSettings: slicerSettings)
    }
}

/// Records that a piece of geometry is a printable ``Component`` that
/// ``Cadova/Geometry3D/onPlatter(removingMaterials:)`` orients, multiplies and packs.
///
/// Only geometry explicitly declared with ``Cadova/Geometry3D/inComponent(_:upDirection:)`` (or its `name:` variant)
/// carries this; the platter ignores everything else, including plain Cadova
/// ``Cadova/Geometry3D/inPart(_:)`` parts. A part with no declared print orientation can't be oriented
/// meaningfully, so it's left out rather than dropped onto the bed in an arbitrary rotation.
///
/// The up direction is stored together with the environment transform in effect where it was declared,
/// so the packer can re-express it in whatever frame it reads — keeping orientation correct even when
/// an enclosing assembly is transformed afterwards. Since each declaration emits into its own part,
/// the pair always describes the geometry it's attached to, never a sibling body of the same component.
struct ComponentData: ResultElement {
    struct Value: Sendable {
        var component: Component
        var upDirection: Direction3D
        var transform: Transform3D

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

private struct ComponentEntry {
    let component: Component
    let packingBody: any Geometry3D
    let placedBody: (Transform2D) -> any Geometry3D
    /// The transform taking this piece from where it sat in the assembly to where it lands on the
    /// plate, for the layout it's finally given. Inverted, it's what tells a slicer where the piece
    /// belongs in the assembled model.
    let platterTransform: (Transform2D) -> Transform3D
}

public extension Geometry3D {
    /// Declares this geometry as the given printable component, for
    /// ``onPlatter(removingMaterials:)``.
    ///
    /// Only components are laid out by ``onPlatter(removingMaterials:)``; plain Cadova
    /// ``Cadova/Geometry3D/inPart(_:)`` parts are left out.
    ///
    /// Each declaration is its own piece. Marking several bodies with the same component is how one
    /// component appears in several places in an assembly — each keeps the orientation and the frame of
    /// the place it was declared, so each is stood up correctly, and they're named after the component
    /// and numbered in the output.
    ///
    /// `upDirection` also informs Cadova's overhang compensation within the geometry, via
    /// ``Cadova/Geometry3D/definingNaturalUpDirection(_:)``, so features inside are built for the
    /// orientation the piece is printed in.
    ///
    /// Any ``Component/slicerSettings`` work whether or not the component goes through
    /// ``onPlatter(removingMaterials:)`` — if it does, the settings follow whatever final
    /// part(s) the layout produces (e.g. numbered copies for a `quantity` above 1).
    ///
    /// - Parameters:
    ///   - component: The component this geometry belongs to.
    ///   - upDirection: The direction, in this geometry's own coordinate system, that should point up
    ///     when it's printed. Defaults to `.up`.
    ///   - part: The part to emit into, from ``Component/makePart()``. Pass one only when something
    ///     else needs the same ``Cadova/Part`` value, such as ``Cadova/Geometry/detachingPart(_:_:)``;
    ///     by default each declaration gets its own, which is what keeps them independent.
    /// - Returns: The geometry declared as that printable component.
    func inComponent(
        _ component: Component,
        upDirection: Direction3D = .up,
        part: Part? = nil
    ) -> any Geometry3D {
        // A fresh part per declaration, so two bodies of one component stay distinguishable all the way
        // to the platter. Sharing one part would merge them, and only one declaration's frame could
        // survive — which used to leave every body but one tilted.
        let part = part ?? component.makePart()

        // `definingNaturalUpDirection` keeps Cadova's overhang compensation working inside the component;
        // the `ComponentData` result element is what the packer reads. The transform in effect here is
        // captured alongside the up direction so the packer can resolve it in its own frame.
        var geometry = definingNaturalUpDirection(upDirection)
            .readingEnvironment(\.transform) { geometry, transform in
                geometry.withResult(ComponentData(.init(
                    component: component, upDirection: upDirection, transform: transform
                )))
            }

        if !component.slicerSettings.isEmpty {
            geometry = geometry
                .modifyingResult(SlicerSettingsEntries.self) {
                    $0.entries.append((part, component.slicerSettings))
                }
                .withArchiveFinalizer { try await SlicerSettingsEntries.writeConfigsIfNeeded(to: $0) }
        }

        return geometry.inPart(part)
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
    ///   - platter: Options that only apply once the component is laid out on a platter, such as
    ///     how many copies to make. See ``PlatterOptions``.
    ///   - color: An optional default color for geometry that doesn't specify its own material.
    ///   - slicerSettings: Per-object slicer settings written into the platter's config sidecars
    ///     (e.g. `[.infillDensity(15)]`), for both Bambu Studio and PrusaSlicer and their forks. See
    ///     ``onPlatter(removingMaterials:)``.
    /// - Returns: The geometry declared as a named printable component.
    func inComponent(
        name: String,
        upDirection: Direction3D = .up,
        platter: PlatterOptions = .default,
        color: Color? = nil,
        slicerSettings: [SlicerSetting] = []
    ) -> any Geometry3D {
        inComponent(
            Component(name, platter: platter, color: color, slicerSettings: slicerSettings),
            upDirection: upDirection
        )
    }

    /// Lays out every printable component in this geometry on a single platter for 3D printing.
    ///
    /// Each component — declared with ``inComponent(_:upDirection:)`` or ``inComponent(name:upDirection:platter:color:slicerSettings:)``
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
    /// - Returns: The components packed onto a platter, each preserved as its own part.
    func onPlatter(removingMaterials: Bool = false) -> any Geometry3D {
        evaluating { base, evaluator in
            @Environment(\.footprintMargin) var margin
            // The frame the layout is read in. Resolving it here, once, is what lets each piece's pose
            // be computed as a single transform below rather than emerging from a chain of modifiers.
            @Environment(\.transform) var readingTransform
            let placed = await packComponents(
                of: base,
                using: evaluator,
                margin: margin,
                readingTransform: readingTransform,
                removingMaterials: removingMaterials
            )
            for component in placed { component }
        }
        // Registered here rather than only where settings are declared: a platter always has an
        // assembled arrangement to record, even when no component configured anything.
        .withArchiveFinalizer { try await SlicerSettingsEntries.writeConfigsIfNeeded(to: $0) }
    }
}

/// Reads each printable component, orients it, drops it to z = 0, packs everything, and returns the
/// placed bodies (each re-wrapped in its own part). Kept as a plain async function — not a geometry
/// builder — so it can use ordinary control flow (loops, `continue`) while gathering the components.
private func packComponents(
    of base: any Geometry3D,
    using evaluator: GeometryEvaluator,
    margin: Double,
    readingTransform: Transform3D,
    removingMaterials: Bool
) async -> [any Geometry3D] {
    let partGeometries = await evaluator.parts(of: base, ofType: .solid)

    // Only declared components participate. Parts with no component data (plain Cadova parts) are
    // skipped rather than guessed at. Reading the data first also gives a stable layout order: several
    // declarations of one component share a name, so position in the assembly breaks the tie.
    var declarations: [(geometry: any Geometry3D, data: ComponentData.Value)] = []
    for (_, partGeometry) in partGeometries {
        guard let data = await evaluator.result(ComponentData.self, of: partGeometry).value else { continue }
        // The catalog exposes nested parts flattened at the top level, so each is laid out on its own.
        // Strip any nested parts (of every semantic) so they don't ride along.
        let geometry = PartSemantic.allCases.reduce(partGeometry) { $0.removingParts(ofType: $1) }
        declarations.append((geometry, data))
    }
    declarations.sort {
        ($0.data.component.name, $0.data.transform.offset.x, $0.data.transform.offset.y, $0.data.transform.offset.z)
            < ($1.data.component.name, $1.data.transform.offset.x, $1.data.transform.offset.y, $1.data.transform.offset.z)
    }

    var entries: [ComponentEntry] = []
    for (geometry, data) in declarations {
        // The pose of each piece is one transform, computed here and used for everything: the packing
        // footprint, the placed body, and the assembled pose recorded for the slicer. Deriving it in
        // more than one place is what once let the footprint and the placed body disagree, so that
        // parts overlapped.
        let rotation = Transform3D.rotation(from: data.resolvedUpDirection(in: readingTransform), to: .up)

        // One disconnected solid of the component, already stood up but not yet dropped or placed.
        func uprightSolid(_ solidIndex: Int?) -> any Geometry3D {
            let upright = geometry.transformed(rotation)
            guard let solidIndex else { return upright }
            return upright.separated { solids in solids[solidIndex] }
        }

        func orientedBody(solidIndex: Int?, drop: Double, placement: Transform2D) -> any Geometry3D {
            uprightSolid(solidIndex).transformed(Transform3D.translation(z: -drop).concatenated(with: placement.transform3D))
        }

        // The solid count is orientation-independent, so read it from the plain geometry.
        let separateSolids = data.component.platter.separateSolids
        let solidCount = separateSolids ? await evaluator.components(of: geometry).count : 1
        // Drop each solid to z = 0, skipping any that are empty (an empty component has no footprint to
        // lay out and would otherwise produce an empty part).
        // How far each upright solid has to fall to rest on z = 0. Measured rather than applied with
        // `aligned(at: .minZ)` so the drop is part of the transform we can hand back later.
        var drops: [(solidIndex: Int?, drop: Double)] = []
        for solidIndex in 0 ..< Swift.max(solidCount, 1) {
            let index: Int? = separateSolids ? solidIndex : nil
            let solid = uprightSolid(index)
            // Skip solids with nothing to lay out. This is not just about genuinely empty components:
            // booleans leave degenerate slivers behind, and separating a body hands each of those out
            // as its own solid. Measuring bounds alone doesn't reject them — a sliver has bounds — so
            // without this check they reach the plate as parts a slicer will happily try to print.
            if await evaluator.isEmpty(solid) { continue }
            guard let bounds = await evaluator.bounds(of: solid) else { continue }
            drops.append((index, bounds.minimum.z))
        }

        for _ in 0 ..< data.component.platter.quantity {
            for (solidIndex, drop) in drops {
                // The full journey from assembled pose to plate: stand up, drop, place.
                func platterTransform(_ placement: Transform2D) -> Transform3D {
                    rotation
                        .concatenated(with: .translation(z: -drop))
                        .concatenated(with: placement.transform3D)
                }
                entries.append(ComponentEntry(
                    component: data.component,
                    packingBody: orientedBody(solidIndex: solidIndex, drop: drop, placement: .identity),
                    placedBody: { placement in
                        orientedBody(solidIndex: solidIndex, drop: drop, placement: placement)
                    },
                    platterTransform: platterTransform
                ))
            }
        }
    }

    // Number the output parts per component, across every declaration, solid and copy it produced, so a
    // component that ends up as several pieces stays individually selectable in a slicer.
    var indicesByComponent: [UUID: [Int]] = [:]
    for (index, entry) in entries.enumerated() {
        indicesByComponent[entry.component.id, default: []].append(index)
    }
    var names = [String](repeating: "", count: entries.count)
    for (_, indices) in indicesByComponent {
        for (number, index) in indices.enumerated() {
            let name = entries[index].component.name
            names[index] = indices.count > 1 ? "\(name) \(number + 1)" : name
        }
    }

    // Lay out the real bodies (footprints need real geometry), then re-wrap each in its own part.
    let packer = Packer(bodies: entries.map(\.packingBody), margin: margin, footprintDetail: 24)
    let transforms = await packer.placements(using: evaluator)

    // The assembled pose each piece is recorded with, which is not simply the inverse of its journey
    // to the plate. Bambu Studio recentres every mesh it imports on its own bounding box and keeps the
    // offset in the instance transform (`bbs_3mf.cpp`, add_volume with modify_to_center_geometry, then
    // the single-volume normalisation). Its assembly view *replaces* that instance transform with the
    // assembled one, so the centring offset disappears and the pose has to put it back — otherwise
    // every piece is displaced by its own plate position and the assembly falls apart.
    var assembledPoses: [Transform3D] = []
    for index in entries.indices {
        let placed = entries[index].placedBody(transforms[index])
        let centre = await evaluator.bounds(of: placed).map { ($0.minimum + $0.maximum) / 2 } ?? .zero
        assembledPoses.append(
            Transform3D.translation(centre)
                .concatenated(with: entries[index].platterTransform(transforms[index]).inverse)
        )
    }

    return entries.indices.map { index -> any Geometry3D in
        let entry = entries[index]
        let placed = entry.placedBody(transforms[index])

        // The settings re-declaration below must key off whichever `Part` instance actually ends up in
        // the output — inComponent's own declaration (against the pre-layout part) won't resolve to a
        // real object id once the layout has renamed or copied it, so it's this final identity that
        // matters. removingMaterials drops the default material from that part as well as stripping the
        // ones applied within the component.
        let outputPart = Part(
            names[index],
            semantic: .solid,
            material: removingMaterials ? nil : entry.component.material
        )
        var result: any Geometry3D = removingMaterials
            ? placed.withoutMaterials().inPart(outputPart)
            : placed.inPart(outputPart)

        let assembledPose = assembledPoses[index]
        result = result.modifyingResult(AssemblyPlacements.self) {
            $0.posesByPart[outputPart] = assembledPose
        }

        let settings = entry.component.slicerSettings
        guard !settings.isEmpty else { return result }
        return result.modifyingResult(SlicerSettingsEntries.self) {
            $0.entries.append((outputPart, settings))
        }
    }
}
