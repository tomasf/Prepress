import Foundation
@_spi(ArchiveFinalizer) import Cadova

/// Per-part slicer settings declared directly on geometry, for whichever part it ends up in.
///
/// Settings declared this way work for any Cadova ``Cadova/Part`` — no ``Component`` and no platter
/// are needed. This is separate from a component's own `settings`, which stay the way to configure a
/// whole component; the two are merged when the archive is written, with a declaration made here
/// winning per key where they overlap, since it's the more specific of the two.
///
/// Each declaration is stamped with an id, which is what makes them separable again. A result element
/// attached inside a part propagates *outward* as well — `inPart` blanks the node but keeps the
/// elements — so a declaration made on a nested part is also visible on the part enclosing it. Reading
/// an enclosing part's declarations therefore means subtracting everything its nested parts claim,
/// otherwise a die would inherit the settings of the pips inside it.
struct PartConfiguration: ResultElement {
    /// In declaration order, so a later declaration wins per key.
    private(set) var declarations: [(id: UUID, settings: ResolvedSlicerSettings)]

    init() { declarations = [] }

    init(combining elements: [PartConfiguration]) {
        // The same declaration reaches here by more than one route — a part's catalog entry carries its
        // own elements as well as propagating them — so identity, not position, decides duplicates.
        var seen: Set<UUID> = []
        declarations = elements.flatMap(\.declarations).filter { seen.insert($0.id).inserted }
    }

    mutating func append(id: UUID, _ settings: ResolvedSlicerSettings) {
        declarations.append((id, settings))
    }

    /// The ids this configuration claims, for subtracting a nested part's declarations from its host's.
    var declarationIDs: Set<UUID> {
        Set(declarations.map(\.id))
    }

    /// Everything declared here that isn't claimed by something nested inside, merged in order.
    func resolved(excluding nested: Set<UUID>) -> ResolvedSlicerSettings {
        var settings = ResolvedSlicerSettings()
        for (id, declaration) in declarations where !nested.contains(id) {
            settings.bambu.merge(declaration.bambu) { _, new in new }
            settings.prusa.merge(declaration.prusa) { _, new in new }
        }
        return settings
    }
}

extension PartConfiguration {
    /// What every part in the archive was configured with via
    /// ``Cadova/Geometry3D/withSlicerSettings(_:)``, each one's nested parts subtracted.
    ///
    /// Reading declarations back per part, rather than off whatever part they were originally declared
    /// against, is what makes this work whether or not packing has renamed or copied that part: it's
    /// the geometry that's queried, and a renamed part's geometry still carries the same declarations.
    static func resolvingEveryPart(in archive: ModelArchive) async -> [Part: ResolvedSlicerSettings] {
        let evaluator = archive.evaluator
        let geometries = await evaluator.parts(of: archive.rootGeometry, ofType: .solid)

        var resolved: [Part: ResolvedSlicerSettings] = [:]
        for (part, geometry) in geometries {
            let own = await resolving(geometry, using: evaluator)
            if !own.isEmpty { resolved[part] = own }
        }
        return resolved
    }

    /// One piece of geometry's own configuration, with everything its nested parts claim subtracted.
    static func resolving(
        _ geometry: any Geometry3D,
        using evaluator: GeometryEvaluator
    ) async -> ResolvedSlicerSettings {
        let configuration = await evaluator.result(PartConfiguration.self, of: geometry)
        guard !configuration.declarations.isEmpty else { return ResolvedSlicerSettings() }

        var nested: Set<UUID> = []
        for (_, nestedGeometry) in await evaluator.parts(of: geometry, ofType: .solid) {
            nested.formUnion(await evaluator.result(PartConfiguration.self, of: nestedGeometry).declarationIDs)
        }
        return configuration.resolved(excluding: nested)
    }

    /// Re-declares an already-resolved value as this geometry's sole configuration, discarding
    /// whatever's already attached here.
    ///
    /// For use after ``resolving(_:using:)`` has subtracted a nested part's contribution from a piece
    /// of geometry that's about to have that nested part stripped out of its catalog (see
    /// ``Cadova/Geometry3D/removingParts(ofType:)``). Stripping clears the catalog entry but not the
    /// result element the nested part's own declaration already propagated into — so left alone, a
    /// later, generic re-resolution over the stripped geometry would find the nested part's
    /// declaration again with nothing left to subtract it against, and rediscover the tainted,
    /// unsubtracted combination instead of the value already resolved here.
    static func replacing(on geometry: any Geometry3D, with settings: ResolvedSlicerSettings) -> any Geometry3D {
        geometry.withResult(PartConfiguration()).modifyingResult(PartConfiguration.self) {
            if !settings.isEmpty { $0.append(id: UUID(), settings) }
        }
    }
}

public extension Geometry3D {
    /// Applies per-object slicer settings to the part this geometry ends up in.
    ///
    /// ```swift
    /// Sphere(radius: 1.5)
    ///     .withSlicerSettings([.infillDensity(15)])
    ///     .inPart(pips)
    /// ```
    ///
    /// The settings are embedded in the exported 3MF, in whichever of the two sidecar formats support
    /// each one, so the same file configures Bambu Studio and its forks as well as PrusaSlicer and
    /// SuperSlicer. This works for any part: a ``Component`` isn't needed, and neither is
    /// ``onPlatter(removingMaterials:)`` — settings on a plain part are a complete use of this.
    ///
    /// - Important: This has to be applied *within* the part it configures, as shown above. Written the
    ///   other way round — `geometry.inPart(pips).withSlicerSettings(...)` — it configures whatever
    ///   part encloses `pips`, if any, because a part captures its contents where it's declared and
    ///   anything chained on afterwards lands outside it.
    ///
    /// Settings declared this way and a component's own `settings` are merged for a
    /// part that has both, with this modifier's settings winning per key where they overlap. Settings
    /// declared on a nested part apply to that part alone, never to the part enclosing it.
    ///
    /// - Parameter settings: The settings to apply, e.g. `[.infillDensity(15)]`.
    /// - Returns: The geometry, with the settings declared for its part.
    func withSlicerSettings(_ settings: [SlicerSetting]) -> any Geometry3D {
        // One id per call site, which is what lets a nested part's declarations be told apart from its
        // host's once both have propagated to the same place.
        let id = UUID()
        return modifyingResult(PartConfiguration.self) { $0.append(id: id, settings.resolved) }
            .withArchiveFinalizer { try await SlicerSettingsEntries.writeConfigsIfNeeded(to: $0) }
    }

    /// Applies per-object slicer settings to the part this geometry ends up in.
    ///
    /// ```swift
    /// Sphere(radius: 1.5)
    ///     .withSlicerSettings(.infillDensity(15), .wallCount(4))
    ///     .inPart(pips)
    /// ```
    ///
    /// The same as ``withSlicerSettings(_:)`` with an array, spelled without the brackets. Pass an
    /// array where the settings already are one.
    ///
    /// - Parameter settings: The settings to apply, e.g. `.infillDensity(15)`.
    /// - Returns: The geometry, with the settings declared for its part.
    func withSlicerSettings(_ settings: SlicerSetting...) -> any Geometry3D {
        withSlicerSettings(settings)
    }
}
