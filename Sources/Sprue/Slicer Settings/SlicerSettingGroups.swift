import Foundation
import Cadova

// Grouped convenience factories for settings that are only meaningful together — the pattern and
// density of the sparse infill, a support type and its distances, and so on. Each returns a single
// `SlicerSetting` carrying several options, so they mix freely with the one-option factories in
// `SlicerSettings.swift`:
//
//     .inComponent(name: "Bracket", settings: [
//         .infill(.gyroid, density: 20),
//         .support(.treeAuto, style: .treeOrganic),
//         .wallCount(4),
//     ])
//
// Every parameter beyond the leading one is optional and defaults to `nil`, meaning *not written* —
// never a value of our own choosing. Writing a default we invented would silently override whatever
// the user configured in their slicer profile for a setting they never asked us to touch.
//
// These are built by combining the single-option factories rather than by assembling config keys
// directly, so each option's per-slicer lowering stays defined in exactly one place.
//
// Slicer support is documented per parameter, following the convention described on `SlicerSetting`:
// a parameter with no slicer note is understood by every slicer Sprue writes for, and one that is
// narrower says so in bold. A group can therefore be partly universal — `.ironing(.top, spacing: 0.1,
// direction: 45°)` sets the spacing everywhere and the direction only for Bambu Studio and its forks.

private extension SlicerSetting {
    /// Combines several settings into one, dropping those whose parameter wasn't specified. Later
    /// entries win per key, matching how `Array.resolved` collapses a whole list.
    init(combining settings: [Self?]) {
        let present = settings.compactMap { $0 }
        self.init(
            bambu: present.reduce(into: [:]) { $0.merge($1.bambu) { _, new in new } },
            prusa: present.reduce(into: [:]) { $0.merge($1.prusa) { _, new in new } }
        )
    }
}

public extension SlicerSetting {
    /// Sparse (internal) infill: the pattern plus the knobs that shape it.
    ///
    /// - Parameters:
    ///   - pattern: The sparse infill pattern. A few patterns exist in only one slicer family — see
    ///     ``InfillPattern``.
    ///   - density: Infill density, as a percentage.
    ///   - anchor: Length of the infill line anchored into the wall, in millimeters.
    ///   - anchorMax: Maximum anchor length, in millimeters.
    ///   - direction: Angle of the infill lines.
    ///   - wallOverlap: Overlap between infill and walls, as a percentage of the line width.
    ///   - minimumArea: Regions smaller than this are filled solid instead, in square millimeters.
    static func infill(
        _ pattern: InfillPattern,
        density: Int? = nil,
        anchor: Double? = nil,
        anchorMax: Double? = nil,
        direction: Angle? = nil,
        wallOverlap: Int? = nil,
        minimumArea: Double? = nil
    ) -> Self {
        .init(combining: [
            .infillPattern(pattern),
            density.map(Self.infillDensity),
            anchor.map(Self.infillAnchor),
            anchorMax.map(Self.infillAnchorMax),
            direction.map(Self.infillDirection),
            wallOverlap.map(Self.infillWallOverlap),
            minimumArea.map(Self.minimumSparseInfillArea),
        ])
    }

    /// Support material: the generation algorithm plus its geometry.
    ///
    /// Naming a type implies `enableSupport(true)` — the type alone does nothing without the enable
    /// flag in either slicer, and having to pass both is an easy way to end up with a part that
    /// silently prints unsupported. Use ``noSupport`` to turn support off.
    ///
    /// - Parameters:
    ///   - type: The support generation algorithm.
    ///   - style: Support structure style. PrusaSlicer's vocabulary is coarser — see ``SupportStyle``.
    ///   - thresholdAngle: Overhangs steeper than this, measured from vertical, get support.
    ///   - onBuildPlateOnly: Whether support only grows from the build plate, never from the model.
    ///   - expansion: How far support is expanded horizontally, in millimeters.
    ///     **Bambu Studio and its forks only.**
    ///   - topZDistance: Gap between the top of support and the model above it, in millimeters.
    ///   - bottomZDistance: Gap between the bottom of support and the model below it, in millimeters.
    ///   - objectXYDistance: Horizontal gap between support and the model, in millimeters.
    ///   - filament: 1-based index of the filament support prints in.
    static func support(
        _ type: SupportType,
        style: SupportStyle? = nil,
        thresholdAngle: Angle? = nil,
        onBuildPlateOnly: Bool? = nil,
        expansion: Double? = nil,
        topZDistance: Double? = nil,
        bottomZDistance: Double? = nil,
        objectXYDistance: Double? = nil,
        filament: Int? = nil
    ) -> Self {
        .init(combining: [
            .enableSupport(true),
            .supportType(type),
            // After `supportType`, which also lowers to a PrusaSlicer style: an explicit style wins.
            style.map(Self.supportStyle),
            thresholdAngle.map(Self.supportThresholdAngle),
            onBuildPlateOnly.map(Self.supportOnBuildPlateOnly),
            expansion.map(Self.supportExpansion),
            topZDistance.map(Self.supportTopZDistance),
            bottomZDistance.map(Self.supportBottomZDistance),
            objectXYDistance.map(Self.supportObjectXYDistance),
            filament.map(Self.supportFilament),
        ])
    }

    /// Disables support for this object, overriding whatever the slicer profile enables.
    static var noSupport: Self {
        .enableSupport(false)
    }

    /// Brim: the type plus its dimensions.
    ///
    /// - Parameters:
    ///   - type: The brim generation strategy. Use `.none` for no brim. ``BrimType/auto`` and
    ///     ``BrimType/painted`` are **Bambu Studio and its forks only.**
    ///   - width: Brim width, in millimeters.
    ///   - objectGap: Gap between the brim and the object, in millimeters.
    ///   - flowRatio: Flow multiplier for brim lines. **OrcaSlicer only.**
    ///   - followsCompensatedOutline: Whether the brim follows the elephant-foot-compensated outline.
    ///     **OrcaSlicer only.**
    static func brim(
        _ type: BrimType,
        width: Double? = nil,
        objectGap: Double? = nil,
        flowRatio: Double? = nil,
        followsCompensatedOutline: Bool? = nil
    ) -> Self {
        .init(combining: [
            .brimType(type),
            width.map(Self.brimWidth),
            objectGap.map(Self.brimObjectGap),
            flowRatio.map(Self.brimFlowRatio),
            followsCompensatedOutline.map(Self.brimFollowsCompensatedOutline),
        ])
    }

    /// Ironing: which surfaces get ironed, plus how.
    ///
    /// - Parameters:
    ///   - type: Which surfaces to iron. Use `.noIroning` to disable.
    ///   - flow: Flow rate while ironing, as a percentage.
    ///   - spacing: Spacing between ironing lines, in millimeters.
    ///   - inset: How far the ironing pattern is inset from the surface edge, in millimeters.
    ///     **Bambu Studio and its forks only.**
    ///   - speed: Ironing speed, in millimeters per second.
    ///   - direction: Angle of the ironing lines.
    ///     **Bambu Studio and its forks only.**
    ///   - expansion: How far ironing extends past the surface. **OrcaSlicer only.**
    static func ironing(
        _ type: IroningType,
        flow: Int? = nil,
        spacing: Double? = nil,
        inset: Double? = nil,
        speed: Double? = nil,
        direction: Angle? = nil,
        expansion: Double? = nil
    ) -> Self {
        .init(combining: [
            .ironingType(type),
            flow.map(Self.ironingFlow),
            spacing.map(Self.ironingSpacing),
            inset.map(Self.ironingInset),
            speed.map(Self.ironingSpeed),
            direction.map(Self.ironingDirection),
            expansion.map(Self.ironingExpansion),
        ])
    }

    /// Seam placement.
    ///
    /// - Parameters:
    ///   - position: The seam positioning strategy.
    ///   - gap: Extra distance the seam is moved away from the model, as a percentage of the nozzle
    ///     diameter. **Bambu Studio and its forks only.**
    static func seam(_ position: SeamPosition, gap: Int? = nil) -> Self {
        .init(combining: [
            .seamPosition(position),
            gap.map(Self.seamGap),
        ])
    }

    /// Where filament purged before printing this object may be flushed.
    ///
    /// - Parameters:
    ///   - intoInfill: Whether purged filament can go into this object's infill.
    ///   - intoObjects: Whether purged filament can go into this object itself.
    ///   - intoSupport: Whether purged filament can go into this object's support.
    ///     **Bambu Studio and its forks only.**
    static func flush(
        intoInfill: Bool? = nil,
        intoObjects: Bool? = nil,
        intoSupport: Bool? = nil
    ) -> Self {
        .init(combining: [
            intoInfill.map(Self.flushIntoInfill),
            intoObjects.map(Self.flushIntoObjects),
            intoSupport.map(Self.flushIntoSupport),
        ])
    }
}
