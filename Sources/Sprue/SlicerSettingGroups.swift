import Foundation

// Grouped convenience factories for settings that are only meaningful together — the pattern and
// density of the sparse infill, a support type and its distances, and so on. Each returns a single
// `SlicerSetting` carrying several key/value pairs, so they mix freely with the one-key factories in
// `SlicerSettings.swift`:
//
//     .asComponent(name: "Bracket", slicerSettings: [
//         .sparseInfill(.gyroid, density: 20),
//         .support(.treeAuto, style: .treeOrganic),
//         .wallLoops(4),
//     ])
//
// Every parameter beyond the leading one is optional and defaults to `nil`, meaning *not written* —
// never a value of our own choosing. Writing a default we invented would silently override whatever
// the user configured in their slicer profile for a setting they never asked us to touch.

private extension SlicerSetting {
    /// Builds a grouped setting, dropping the pairs whose value wasn't specified. `KeyValuePairs`
    /// rather than a dictionary literal so the call sites read in a deliberate order.
    init(_ pairs: KeyValuePairs<SlicerSettingKey, String?>) {
        self.init(pairs.reduce(into: [:]) { values, pair in
            if let value = pair.value { values[pair.key] = value }
        })
    }

    static func number<Value: LosslessStringConvertible>(_ value: Value?) -> String? {
        value.map { String($0) }
    }

    static func percent(_ value: Int?) -> String? {
        value.map { "\($0)%" }
    }

    static func flag(_ value: Bool?) -> String? {
        value.map { $0 ? "1" : "0" }
    }
}

public extension SlicerSetting {
    /// Sparse (internal) infill: the pattern plus the knobs that shape it.
    ///
    /// - Parameters:
    ///   - pattern: The sparse infill pattern.
    ///   - density: Infill density, as a percentage.
    ///   - anchor: Length of the infill line anchored into the wall, in millimeters.
    ///   - anchorMax: Maximum anchor length, in millimeters.
    ///   - direction: Angle of the infill lines, in degrees.
    ///   - wallOverlap: Overlap between infill and walls, as a percentage of the line width.
    ///   - minimumArea: Regions smaller than this are filled solid instead, in square millimeters.
    static func sparseInfill(
        _ pattern: InfillPattern,
        density: Int? = nil,
        anchor: Double? = nil,
        anchorMax: Double? = nil,
        direction: Double? = nil,
        wallOverlap: Int? = nil,
        minimumArea: Double? = nil
    ) -> Self {
        .init([
            .sparseInfillPattern: pattern.rawValue,
            .sparseInfillDensity: percent(density),
            .sparseInfillAnchor: number(anchor),
            .sparseInfillAnchorMax: number(anchorMax),
            .infillDirection: number(direction),
            .infillWallOverlap: percent(wallOverlap),
            .minimumSparseInfillArea: number(minimumArea),
        ])
    }

    /// Support material: the generation algorithm plus its geometry.
    ///
    /// Naming a type implies `enableSupport(true)` — the type alone does nothing in Bambu Studio
    /// without the enable flag, and having to pass both is an easy way to end up with a part that
    /// silently prints unsupported. Use ``noSupport`` to turn support off.
    ///
    /// - Parameters:
    ///   - type: The support generation algorithm.
    ///   - style: Support structure style.
    ///   - thresholdAngle: Overhangs steeper than this get support, in degrees.
    ///   - onBuildPlateOnly: Whether support only grows from the build plate, never from the model.
    ///   - expansion: How far support is expanded horizontally, in millimeters.
    ///   - topZDistance: Gap between the top of support and the model above it, in millimeters.
    ///   - bottomZDistance: Gap between the bottom of support and the model below it, in millimeters.
    ///   - objectXYDistance: Horizontal gap between support and the model, in millimeters.
    ///   - filament: 1-based index of the filament support prints in.
    static func support(
        _ type: SupportType,
        style: SupportStyle? = nil,
        thresholdAngle: Int? = nil,
        onBuildPlateOnly: Bool? = nil,
        expansion: Double? = nil,
        topZDistance: Double? = nil,
        bottomZDistance: Double? = nil,
        objectXYDistance: Double? = nil,
        filament: Int? = nil
    ) -> Self {
        .init([
            .enableSupport: flag(true),
            .supportType: type.rawValue,
            .supportStyle: style?.rawValue,
            .supportThresholdAngle: number(thresholdAngle),
            .supportOnBuildPlateOnly: flag(onBuildPlateOnly),
            .supportExpansion: number(expansion),
            .supportTopZDistance: number(topZDistance),
            .supportBottomZDistance: number(bottomZDistance),
            .supportObjectXYDistance: number(objectXYDistance),
            .supportFilament: number(filament),
        ])
    }

    /// Disables support for this object, overriding whatever the slicer profile enables.
    static var noSupport: Self {
        .init(key: .enableSupport, value: false)
    }

    /// Brim: the type plus its dimensions.
    ///
    /// - Parameters:
    ///   - type: The brim generation strategy. Use `.none` for no brim.
    ///   - width: Brim width, in millimeters.
    ///   - objectGap: Gap between the brim and the object, in millimeters.
    ///   - flowRatio: Flow multiplier for brim lines. **OrcaSlicer only.**
    ///   - useEfcOutline: Whether the brim follows the elephant-foot-compensated outline.
    ///     **OrcaSlicer only.**
    static func brim(
        _ type: BrimType,
        width: Double? = nil,
        objectGap: Double? = nil,
        flowRatio: Double? = nil,
        useEfcOutline: Bool? = nil
    ) -> Self {
        .init([
            .brimType: type.rawValue,
            .brimWidth: number(width),
            .brimObjectGap: number(objectGap),
            .brimFlowRatio: number(flowRatio),
            .brimUseEfcOutline: flag(useEfcOutline),
        ])
    }

    /// Ironing: which surfaces get ironed, plus how.
    ///
    /// - Parameters:
    ///   - type: Which surfaces to iron. Use `.noIroning` to disable.
    ///   - flow: Flow rate while ironing, as a percentage.
    ///   - spacing: Spacing between ironing lines, in millimeters.
    ///   - inset: How far the ironing pattern is inset from the surface edge, in millimeters.
    ///   - speed: Ironing speed, in millimeters per second.
    ///   - direction: Angle of the ironing lines, in degrees.
    ///   - expansion: How far ironing extends past the surface. **OrcaSlicer only.**
    static func ironing(
        _ type: IroningType,
        flow: Int? = nil,
        spacing: Double? = nil,
        inset: Double? = nil,
        speed: Double? = nil,
        direction: Double? = nil,
        expansion: Double? = nil
    ) -> Self {
        .init([
            .ironingType: type.rawValue,
            .ironingFlow: percent(flow),
            .ironingSpacing: number(spacing),
            .ironingInset: number(inset),
            .ironingSpeed: number(speed),
            .ironingDirection: number(direction),
            .ironingExpansion: number(expansion),
        ])
    }

    /// Seam placement.
    ///
    /// - Parameters:
    ///   - position: The seam positioning strategy.
    ///   - gap: Extra distance the seam is moved away from the model, as a percentage of the nozzle
    ///     diameter.
    static func seam(_ position: SeamPosition, gap: Int? = nil) -> Self {
        .init([
            .seamPosition: position.rawValue,
            .seamGap: percent(gap),
        ])
    }

    /// Where filament purged before printing this object may be flushed.
    ///
    /// - Parameters:
    ///   - intoInfill: Whether purged filament can go into this object's infill.
    ///   - intoObjects: Whether purged filament can go into this object itself.
    ///   - intoSupport: Whether purged filament can go into this object's support.
    static func flush(
        intoInfill: Bool? = nil,
        intoObjects: Bool? = nil,
        intoSupport: Bool? = nil
    ) -> Self {
        .init([
            .flushIntoInfill: flag(intoInfill),
            .flushIntoObjects: flag(intoObjects),
            .flushIntoSupport: flag(intoSupport),
        ])
    }
}
