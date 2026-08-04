import Foundation
import Cadova
internal import Nodal

// MARK: - Enumerated setting values

/// Infill/surface fill pattern. Bambu Studio's exact accepted raw values and their meaning, verified
/// against its source (`PrintConfig.cpp`'s `sparse_infill_pattern`/`top_surface_pattern` definitions).
///
/// Not every case is valid for every pattern-typed setting: ``SlicerSetting/topSurfacePattern(_:)``,
/// ``SlicerSetting/bottomSurfacePattern(_:)``, and ``SlicerSetting/internalSolidInfillPattern(_:)``
/// only accept `concentric`, `rectilinear`, `monotonic`, `monotonicLine`, `alignedRectilinear`,
/// `hilbertCurve`, `archimedeanChords`, and `octagramSpiral` — the rest are only meaningful for
/// ``SlicerSetting/sparseInfillPattern(_:)``.
///
/// - Note: Bambu's raw value for `rectilinear` is, confusingly, `"zig-zag"` — a legacy name from
///   before the pattern was renamed in the UI. A separate, distinct `zigzag` case (no hyphen) exists
///   for the actual "Zig Zag" pattern; the two are not aliases of each other.
public enum InfillPattern: String, Sendable {
    case concentric
    case rectilinear = "zig-zag"
    case grid
    case line
    case cubic
    case triangles
    case triHexagon = "tri-hexagon"
    case gyroid
    case honeycomb
    case adaptiveCubic = "adaptivecubic"
    case alignedRectilinear = "alignedrectilinear"
    case honeycomb3D = "3dhoneycomb"
    case hilbertCurve = "hilbertcurve"
    case archimedeanChords = "archimedeanchords"
    case octagramSpiral = "octagramspiral"
    case supportCubic = "supportcubic"
    case lightning
    case crossHatch = "crosshatch"
    case zigzag
    case crossZag = "crosszag"
    case lockedZag = "lockedzag"
    case monotonic
    case monotonicLine = "monotonicline"
}

/// Seam positioning strategy.
public enum SeamPosition: String, Sendable {
    case nearest, aligned, back, random
}

/// Ironing mode applied to top surfaces.
public enum IroningType: String, Sendable {
    case noIroning = "no ironing"
    case top
    case topmost
    case solid
}

/// Support generation algorithm.
public enum SupportType: String, Sendable {
    case normalAuto = "normal(auto)"
    case treeAuto = "tree(auto)"
    case normalManual = "normal(manual)"
    case treeManual = "tree(manual)"
}

/// Support structure style.
public enum SupportStyle: String, Sendable {
    case `default`
    case grid
    case snug
    case treeSlim = "tree_slim"
    case treeStrong = "tree_strong"
    case treeHybrid = "tree_hybrid"
    case treeOrganic = "tree_organic"
}

/// Support base (interface/raft-like) fill pattern.
public enum SupportBasePattern: String, Sendable {
    case `default`
    case rectilinear
    case rectilinearGrid = "rectilinear-grid"
    case honeycomb
    case lightning
    case hollow
}

/// Brim generation strategy.
public enum BrimType: String, Sendable {
    case auto = "auto_brim"
    case painted = "brim_ears"
    case outerOnly = "outer_only"
    case innerOnly = "inner_only"
    case outerAndInner = "outer_and_inner"
    case none = "no_brim"
}

/// Wall printing order.
public enum WallSequence: String, Sendable {
    case innerOuter = "inner wall/outer wall"
    case outerInner = "outer wall/inner wall"
    case innerOuterInner = "inner-outer-inner wall"
}

/// Direction top-surface expansion grows in. OrcaSlicer only.
public enum TopSurfaceExpansionDirection: String, Sendable {
    case inwardAndOutward = "inward_and_outward"
    case inward
    case outward
}

// MARK: - Setting keys

/// A slicer print-setting option, identified by its underlying config key.
///
/// This mirrors the options exposed in Bambu Studio's own per-object/per-part settings menu — the
/// same curated set defined in its source as `OBJECT_CATEGORY_SETTINGS`/`PART_CATEGORY_SETTINGS`
/// (`GUI_Factories.cpp`) — rather than every print option that theoretically exists in its config
/// system (many of the rest are printer/filament-level, or per-extruder array values that don't have
/// clear single-value semantics as a per-object override). It also includes the equivalent curated
/// set from two popular Bambu Studio forks, OrcaSlicer and Creality Print, for options they add that
/// Bambu Studio doesn't have — those are marked as such below. All three read the same
/// `model_settings.config` sidecar format, so a key one fork doesn't recognize is simply ignored by
/// it rather than causing an error.
///
/// Since this is a plain `String`-backed enum, it's `RawRepresentable`, so a key not listed here can
/// still be used via `SlicerSettingKey(rawValue: "some_other_key")`.
public enum SlicerSettingKey: String, Sendable {
    // Quality
    case layerHeight = "layer_height"
    case wallSequence = "wall_sequence"
    case seamPosition = "seam_position"
    case seamGap = "seam_gap"
    case wipeSpeed = "wipe_speed"
    case sliceClosingRadius = "slice_closing_radius"
    case resolution
    case xyHoleCompensation = "xy_hole_compensation"
    case xyContourCompensation = "xy_contour_compensation"
    case elephantFootCompensation = "elefant_foot_compensation"
    case preciseZHeight = "precise_z_height"

    // Support & adhesion
    case brimType = "brim_type"
    case brimWidth = "brim_width"
    case brimObjectGap = "brim_object_gap"
    case enableSupport = "enable_support"
    case supportType = "support_type"
    case supportThresholdAngle = "support_threshold_angle"
    case supportOnBuildPlateOnly = "support_on_build_plate_only"
    case supportFilament = "support_filament"
    case supportInterfaceFilament = "support_interface_filament"
    case supportExpansion = "support_expansion"
    case supportStyle = "support_style"
    case treeSupportBranchAngle = "tree_support_branch_angle"
    case treeSupportWallCount = "tree_support_wall_count"
    case treeSupportBranchDiameterAngle = "tree_support_branch_diameter_angle"
    case supportTopZDistance = "support_top_z_distance"
    case supportBottomZDistance = "support_bottom_z_distance"
    case supportBasePattern = "support_base_pattern"
    case supportBasePatternSpacing = "support_base_pattern_spacing"
    case supportInterfaceTopLayers = "support_interface_top_layers"
    case supportInterfaceBottomLayers = "support_interface_bottom_layers"
    case supportInterfaceSpacing = "support_interface_spacing"
    case supportBottomInterfaceSpacing = "support_bottom_interface_spacing"
    case supportObjectXYDistance = "support_object_xy_distance"
    case bridgeNoSupport = "bridge_no_support"
    case maxBridgeLength = "max_bridge_length"
    case supportCriticalRegionsOnly = "support_critical_regions_only"
    case supportRemoveSmallOverhang = "support_remove_small_overhang"
    case supportObjectFirstLayerGap = "support_object_first_layer_gap"

    // Ironing
    case ironingType = "ironing_type"
    case ironingFlow = "ironing_flow"
    case ironingSpacing = "ironing_spacing"
    case ironingInset = "ironing_inset"
    case ironingSpeed = "ironing_speed"
    case ironingDirection = "ironing_direction"

    // Strength / infill
    case wallLoops = "wall_loops"
    case topShellLayers = "top_shell_layers"
    case topShellThickness = "top_shell_thickness"
    case bottomShellLayers = "bottom_shell_layers"
    case bottomShellThickness = "bottom_shell_thickness"
    case sparseInfillDensity = "sparse_infill_density"
    case sparseInfillPattern = "sparse_infill_pattern"
    case sparseInfillAnchor = "sparse_infill_anchor"
    case sparseInfillAnchorMax = "sparse_infill_anchor_max"
    case topSurfacePattern = "top_surface_pattern"
    case bottomSurfacePattern = "bottom_surface_pattern"
    case internalSolidInfillPattern = "internal_solid_infill_pattern"
    case infillCombination = "infill_combination"
    case infillWallOverlap = "infill_wall_overlap"
    case infillDirection = "infill_direction"
    case bridgeAngle = "bridge_angle"
    case minimumSparseInfillArea = "minimum_sparse_infill_area"

    // Multi-material
    case extruder
    case flushIntoInfill = "flush_into_infill"
    case flushIntoObjects = "flush_into_objects"
    case flushIntoSupport = "flush_into_support"

    // MARK: OrcaSlicer extensions (not recognized by vanilla Bambu Studio)

    case makeOverhangPrintableAngle = "make_overhang_printable_angle"
    case makeOverhangPrintableHoleSize = "make_overhang_printable_hole_size"
    case makeOverhangPrintable = "make_overhang_printable"
    case brimFlowRatio = "brim_flow_ratio"
    case brimUseEfcOutline = "brim_use_efc_outline"
    case supportThresholdOverlap = "support_threshold_overlap"
    case treeSupportBrimWidth = "tree_support_brim_width"
    case treeSupportBranchAngleOrganic = "tree_support_branch_angle_organic"
    case bridgeFlow = "bridge_flow"
    case bridgeDensity = "bridge_density"
    case ironingExpansion = "ironing_expansion"
    case zContouringEnabled = "zaa_enabled"
    case zContouringMinimizeWallHeightAngle = "zaa_minimize_perimeter_height"
    case zContouringDisableAlternatingFillDirection = "zaa_dont_alternate_fill_direction"
    case zContouringMinimumZHeight = "zaa_min_z"
    case topSurfaceDensity = "top_surface_density"
    case bottomSurfaceDensity = "bottom_surface_density"
    case fillMultiline = "fill_multiline"
    case lateralLatticeAngle1 = "lateral_lattice_angle_1"
    case lateralLatticeAngle2 = "lateral_lattice_angle_2"
    case infillOverhangAngle = "infill_overhang_angle"
    case lightningOverhangAngle = "lightning_overhang_angle"
    case lightningPruneAngle = "lightning_prune_angle"
    case lightningStraighteningAngle = "lightning_straightening_angle"
    /// OrcaSlicer's (and Creality Print's) renamed successor to ``sparseInfillAnchor``.
    case infillAnchor = "infill_anchor"
    /// OrcaSlicer's (and Creality Print's) renamed successor to ``sparseInfillAnchorMax``.
    case infillAnchorMax = "infill_anchor_max"
    case topSurfaceExpansion = "top_surface_expansion"
    case topSurfaceExpansionMargin = "top_surface_expansion_margin"
    case topSurfaceExpansionDirection = "top_surface_expansion_direction"
    case alignInfillDirectionToModel = "align_infill_direction_to_model"
    case extraSolidInfills = "extra_solid_infills"
    case infillCombinationMaxLayerHeight = "infill_combination_max_layer_height"
    case topBottomInfillWallOverlap = "top_bottom_infill_wall_overlap"
    case solidInfillDirection = "solid_infill_direction"
    case topLayerDirection = "top_layer_direction"
    case bottomLayerDirection = "bottom_layer_direction"
    case internalBridgeAngle = "internal_bridge_angle"

    // MARK: Creality Print extensions (not recognized by vanilla Bambu Studio)

    case treeSupportWallCountTree = "tree_support_wall_count_tree"
    case supportBasePatternTree = "support_base_pattern_tree"
    case supportInterfaceMinArea = "support_interface_min_area"
    case treeSupportOrganicValidateRepair = "tree_support_organic_validate_repair"
    case rotateSolidInfillDirection = "rotate_solid_infill_direction"
    case overhangSpeedClassic = "overhang_speed_classic"
}

// MARK: - Setting values

/// A single typed slicer print-setting value, ready to be written into a `model_settings.config`
/// sidecar. Construct these through the static factory methods below (e.g. `.enableSupport(true)`,
/// `.sparseInfillDensity(15)`) rather than the memberwise initializer, so each setting's value can
/// only be constructed with the Swift type Bambu Studio actually expects for that key.
public struct SlicerSetting: Sendable {
    let key: SlicerSettingKey
    let value: String
}

private extension SlicerSetting {
    static func percent(_ key: SlicerSettingKey, _ value: Int) -> Self {
        .init(key: key, value: "\(value)%")
    }
}

public extension SlicerSetting {
    // MARK: Quality

    /// Layer height, in millimeters.
    static func layerHeight(_ millimeters: Double) -> Self {
        .init(key: .layerHeight, value: String(millimeters))
    }

    /// Wall printing order.
    static func wallSequence(_ sequence: WallSequence) -> Self {
        .init(key: .wallSequence, value: sequence.rawValue)
    }

    /// Seam positioning strategy.
    static func seamPosition(_ position: SeamPosition) -> Self {
        .init(key: .seamPosition, value: position.rawValue)
    }

    /// Extra distance to move the seam away from the model, as a percentage of the nozzle diameter.
    static func seamGap(_ percent: Int) -> Self {
        .percent(.seamGap, percent)
    }

    /// Speed of the wipe move after retraction, as a percentage of the outer wall speed.
    static func wipeSpeed(_ percent: Int) -> Self {
        .percent(.wipeSpeed, percent)
    }

    /// Maximum radius of gaps closed during slicing, in millimeters.
    static func sliceClosingRadius(_ millimeters: Double) -> Self {
        .init(key: .sliceClosingRadius, value: String(millimeters))
    }

    /// Slicing resolution, in millimeters.
    static func resolution(_ millimeters: Double) -> Self {
        .init(key: .resolution, value: String(millimeters))
    }

    /// XY compensation applied to holes, in millimeters (positive values enlarge holes).
    static func xyHoleCompensation(_ millimeters: Double) -> Self {
        .init(key: .xyHoleCompensation, value: String(millimeters))
    }

    /// XY compensation applied to outer contours, in millimeters (positive values shrink the part).
    static func xyContourCompensation(_ millimeters: Double) -> Self {
        .init(key: .xyContourCompensation, value: String(millimeters))
    }

    /// Elephant foot compensation, in millimeters.
    static func elephantFootCompensation(_ millimeters: Double) -> Self {
        .init(key: .elephantFootCompensation, value: String(millimeters))
    }

    /// Whether to use precise Z height, ignoring the printer's layer height rounding.
    static func preciseZHeight(_ value: Bool) -> Self {
        .init(key: .preciseZHeight, value: value ? "1" : "0")
    }

    // MARK: Support & adhesion

    /// Brim generation strategy.
    static func brimType(_ type: BrimType) -> Self {
        .init(key: .brimType, value: type.rawValue)
    }

    /// Brim width, in millimeters.
    static func brimWidth(_ millimeters: Double) -> Self {
        .init(key: .brimWidth, value: String(millimeters))
    }

    /// Gap left between the brim and the object, in millimeters.
    static func brimObjectGap(_ millimeters: Double) -> Self {
        .init(key: .brimObjectGap, value: String(millimeters))
    }

    /// Whether support material is generated for this object.
    static func enableSupport(_ value: Bool) -> Self {
        .init(key: .enableSupport, value: value ? "1" : "0")
    }

    /// Support generation algorithm.
    static func supportType(_ type: SupportType) -> Self {
        .init(key: .supportType, value: type.rawValue)
    }

    /// Overhang threshold angle (from vertical) that triggers support generation, in degrees.
    static func supportThresholdAngle(_ degrees: Int) -> Self {
        .init(key: .supportThresholdAngle, value: String(degrees))
    }

    /// Whether support is only generated where it touches the build plate.
    static func supportOnBuildPlateOnly(_ value: Bool) -> Self {
        .init(key: .supportOnBuildPlateOnly, value: value ? "1" : "0")
    }

    /// The (1-based) extruder used to print support.
    static func supportFilament(_ number: Int) -> Self {
        .init(key: .supportFilament, value: String(number))
    }

    /// The (1-based) extruder used to print the support interface.
    static func supportInterfaceFilament(_ number: Int) -> Self {
        .init(key: .supportInterfaceFilament, value: String(number))
    }

    /// Horizontal expansion applied to support relative to the model, in millimeters.
    static func supportExpansion(_ millimeters: Double) -> Self {
        .init(key: .supportExpansion, value: String(millimeters))
    }

    /// Support structure style.
    static func supportStyle(_ style: SupportStyle) -> Self {
        .init(key: .supportStyle, value: style.rawValue)
    }

    /// Tree support branch angle, in degrees.
    static func treeSupportBranchAngle(_ degrees: Double) -> Self {
        .init(key: .treeSupportBranchAngle, value: String(degrees))
    }

    /// Number of walls supporting the branches of a tree support.
    static func treeSupportWallCount(_ count: Int) -> Self {
        .init(key: .treeSupportWallCount, value: String(count))
    }

    /// Angle at which tree support branches increase in diameter, in degrees.
    static func treeSupportBranchDiameterAngle(_ degrees: Double) -> Self {
        .init(key: .treeSupportBranchDiameterAngle, value: String(degrees))
    }

    /// Vertical gap between the top of support and the model above it, in millimeters.
    static func supportTopZDistance(_ millimeters: Double) -> Self {
        .init(key: .supportTopZDistance, value: String(millimeters))
    }

    /// Vertical gap between the model and the support below it, in millimeters.
    static func supportBottomZDistance(_ millimeters: Double) -> Self {
        .init(key: .supportBottomZDistance, value: String(millimeters))
    }

    /// Support base (interface/raft-like) fill pattern.
    static func supportBasePattern(_ pattern: SupportBasePattern) -> Self {
        .init(key: .supportBasePattern, value: pattern.rawValue)
    }

    /// Spacing between lines of the support base pattern, in millimeters.
    static func supportBasePatternSpacing(_ millimeters: Double) -> Self {
        .init(key: .supportBasePatternSpacing, value: String(millimeters))
    }

    /// Number of solid support interface layers, at the top of the support.
    static func supportInterfaceTopLayers(_ count: Int) -> Self {
        .init(key: .supportInterfaceTopLayers, value: String(count))
    }

    /// Number of solid support interface layers, at the bottom of the support.
    static func supportInterfaceBottomLayers(_ count: Int) -> Self {
        .init(key: .supportInterfaceBottomLayers, value: String(count))
    }

    /// Spacing between lines of the support interface, in millimeters.
    static func supportInterfaceSpacing(_ millimeters: Double) -> Self {
        .init(key: .supportInterfaceSpacing, value: String(millimeters))
    }

    /// Spacing between lines of the bottom support interface, in millimeters.
    static func supportBottomInterfaceSpacing(_ millimeters: Double) -> Self {
        .init(key: .supportBottomInterfaceSpacing, value: String(millimeters))
    }

    /// Horizontal clearance between support and the model, in millimeters.
    static func supportObjectXYDistance(_ millimeters: Double) -> Self {
        .init(key: .supportObjectXYDistance, value: String(millimeters))
    }

    /// Whether to disable support generation under bridges.
    static func bridgeNoSupport(_ value: Bool) -> Self {
        .init(key: .bridgeNoSupport, value: value ? "1" : "0")
    }

    /// Maximum bridge length printed without support, in millimeters.
    static func maxBridgeLength(_ millimeters: Double) -> Self {
        .init(key: .maxBridgeLength, value: String(millimeters))
    }

    /// Whether support is only generated for critical (large, unsupported) regions.
    static func supportCriticalRegionsOnly(_ value: Bool) -> Self {
        .init(key: .supportCriticalRegionsOnly, value: value ? "1" : "0")
    }

    /// Whether small overhang areas are excluded from support generation.
    static func supportRemoveSmallOverhang(_ value: Bool) -> Self {
        .init(key: .supportRemoveSmallOverhang, value: value ? "1" : "0")
    }

    /// Extra gap between the object's first layer and support, in millimeters.
    static func supportObjectFirstLayerGap(_ millimeters: Double) -> Self {
        .init(key: .supportObjectFirstLayerGap, value: String(millimeters))
    }

    // MARK: Ironing

    /// Ironing mode applied to top surfaces.
    static func ironingType(_ type: IroningType) -> Self {
        .init(key: .ironingType, value: type.rawValue)
    }

    /// Flow rate ratio used while ironing, as a whole-number percentage.
    static func ironingFlow(_ percent: Int) -> Self {
        .percent(.ironingFlow, percent)
    }

    /// Spacing between ironing passes, in millimeters.
    static func ironingSpacing(_ millimeters: Double) -> Self {
        .init(key: .ironingSpacing, value: String(millimeters))
    }

    /// Distance ironing is inset from the perimeter, in millimeters.
    static func ironingInset(_ millimeters: Double) -> Self {
        .init(key: .ironingInset, value: String(millimeters))
    }

    /// Ironing speed, in millimeters per second.
    static func ironingSpeed(_ millimetersPerSecond: Double) -> Self {
        .init(key: .ironingSpeed, value: String(millimetersPerSecond))
    }

    /// Ironing line direction, in degrees.
    static func ironingDirection(_ degrees: Double) -> Self {
        .init(key: .ironingDirection, value: String(degrees))
    }

    // MARK: Strength / infill

    /// Number of perimeter walls.
    static func wallLoops(_ count: Int) -> Self {
        .init(key: .wallLoops, value: String(count))
    }

    /// Number of solid top layers.
    static func topShellLayers(_ count: Int) -> Self {
        .init(key: .topShellLayers, value: String(count))
    }

    /// Minimum thickness of solid top shell, in millimeters (adds layers beyond `topShellLayers` if needed).
    static func topShellThickness(_ millimeters: Double) -> Self {
        .init(key: .topShellThickness, value: String(millimeters))
    }

    /// Number of solid bottom layers.
    static func bottomShellLayers(_ count: Int) -> Self {
        .init(key: .bottomShellLayers, value: String(count))
    }

    /// Minimum thickness of solid bottom shell, in millimeters (adds layers beyond `bottomShellLayers` if needed).
    static func bottomShellThickness(_ millimeters: Double) -> Self {
        .init(key: .bottomShellThickness, value: String(millimeters))
    }

    /// Sparse (infill) density, as a whole-number percentage (e.g. `15` for 15%).
    static func sparseInfillDensity(_ percent: Int) -> Self {
        .percent(.sparseInfillDensity, percent)
    }

    /// Sparse (infill) pattern.
    static func sparseInfillPattern(_ pattern: InfillPattern) -> Self {
        .init(key: .sparseInfillPattern, value: pattern.rawValue)
    }

    /// Length of the infill anchor along the perimeter, in millimeters.
    ///
    /// Bambu Studio also accepts a percentage for this option; use ``raw(_:_:)`` (e.g.
    /// `.raw(.sparseInfillAnchor, "50%")`) if you need that form.
    static func sparseInfillAnchor(_ millimeters: Double) -> Self {
        .init(key: .sparseInfillAnchor, value: String(millimeters))
    }

    /// Maximum length of the infill anchor along the perimeter, in millimeters.
    ///
    /// Bambu Studio also accepts a percentage for this option; use ``raw(_:_:)`` (e.g.
    /// `.raw(.sparseInfillAnchorMax, "50%")`) if you need that form.
    static func sparseInfillAnchorMax(_ millimeters: Double) -> Self {
        .init(key: .sparseInfillAnchorMax, value: String(millimeters))
    }

    /// Top surface fill pattern. Only a subset of ``InfillPattern`` applies here — see its documentation.
    static func topSurfacePattern(_ pattern: InfillPattern) -> Self {
        .init(key: .topSurfacePattern, value: pattern.rawValue)
    }

    /// Bottom surface fill pattern. Only a subset of ``InfillPattern`` applies here — see its documentation.
    static func bottomSurfacePattern(_ pattern: InfillPattern) -> Self {
        .init(key: .bottomSurfacePattern, value: pattern.rawValue)
    }

    /// Internal solid infill pattern. Only a subset of ``InfillPattern`` applies here — see its documentation.
    static func internalSolidInfillPattern(_ pattern: InfillPattern) -> Self {
        .init(key: .internalSolidInfillPattern, value: pattern.rawValue)
    }

    /// Whether sparse infill is combined across multiple layers to reduce print time.
    static func infillCombination(_ value: Bool) -> Self {
        .init(key: .infillCombination, value: value ? "1" : "0")
    }

    /// Overlap between infill and walls, as a whole-number percentage of the extrusion width.
    static func infillWallOverlap(_ percent: Int) -> Self {
        .percent(.infillWallOverlap, percent)
    }

    /// Infill line direction, in degrees.
    static func infillDirection(_ degrees: Double) -> Self {
        .init(key: .infillDirection, value: String(degrees))
    }

    /// Angle used for bridge infill, in degrees.
    static func bridgeAngle(_ degrees: Double) -> Self {
        .init(key: .bridgeAngle, value: String(degrees))
    }

    /// Below this area, in square millimeters, sparse infill regions are filled solid instead.
    static func minimumSparseInfillArea(_ squareMillimeters: Double) -> Self {
        .init(key: .minimumSparseInfillArea, value: String(squareMillimeters))
    }

    // MARK: Multi-material

    /// The (1-based) extruder this object is assigned to print with.
    static func extruder(_ number: Int) -> Self {
        .init(key: .extruder, value: String(number))
    }

    /// Whether filament purged before printing this object can be flushed into its own infill.
    static func flushIntoInfill(_ value: Bool) -> Self {
        .init(key: .flushIntoInfill, value: value ? "1" : "0")
    }

    /// Whether filament purged before printing this object can be flushed into other objects.
    static func flushIntoObjects(_ value: Bool) -> Self {
        .init(key: .flushIntoObjects, value: value ? "1" : "0")
    }

    /// Whether filament purged before printing this object can be flushed into support.
    static func flushIntoSupport(_ value: Bool) -> Self {
        .init(key: .flushIntoSupport, value: value ? "1" : "0")
    }

    /// A raw key/value pair, for slicer options not covered by a named case above.
    static func raw(_ key: SlicerSettingKey, _ value: String) -> Self {
        .init(key: key, value: value)
    }
}

// MARK: - OrcaSlicer extensions

/// Settings recognized by OrcaSlicer but not vanilla Bambu Studio. Several of these (noted below) are
/// also recognized by Creality Print, which inherited them from Orca; genuinely Creality-only settings
/// are in a separate extension.
public extension SlicerSetting {
    /// Overhang angle (from vertical) beyond which walls are made printable without support, in
    /// degrees. **OrcaSlicer only.**
    static func makeOverhangPrintableAngle(_ degrees: Double) -> Self {
        .init(key: .makeOverhangPrintableAngle, value: String(degrees))
    }

    /// Maximum size of a hole that "make overhang printable" will fill in, in millimeters.
    /// **OrcaSlicer only.**
    static func makeOverhangPrintableHoleSize(_ millimeters: Double) -> Self {
        .init(key: .makeOverhangPrintableHoleSize, value: String(millimeters))
    }

    /// Whether steep overhangs are reworked so they can be printed without support. **OrcaSlicer only.**
    static func makeOverhangPrintable(_ value: Bool) -> Self {
        .init(key: .makeOverhangPrintable, value: value ? "1" : "0")
    }

    /// Flow ratio used for the brim, relative to the normal flow. **OrcaSlicer only.**
    static func brimFlowRatio(_ ratio: Double) -> Self {
        .init(key: .brimFlowRatio, value: String(ratio))
    }

    /// Whether the brim follows the elephant-foot-compensated outline instead of the nominal one.
    /// **OrcaSlicer only.**
    static func brimUseEfcOutline(_ value: Bool) -> Self {
        .init(key: .brimUseEfcOutline, value: value ? "1" : "0")
    }

    /// Overlap fraction, as a whole-number percentage, needed before an overhang triggers support.
    /// **OrcaSlicer only.**
    static func supportThresholdOverlap(_ percent: Int) -> Self {
        .percent(.supportThresholdOverlap, percent)
    }

    /// Brim width around tree supports, in millimeters. **OrcaSlicer and Creality Print.**
    static func treeSupportBrimWidth(_ millimeters: Double) -> Self {
        .init(key: .treeSupportBrimWidth, value: String(millimeters))
    }

    /// Branch angle for organic-style tree supports, in degrees. **OrcaSlicer and Creality Print.**
    static func treeSupportBranchAngleOrganic(_ degrees: Double) -> Self {
        .init(key: .treeSupportBranchAngleOrganic, value: String(degrees))
    }

    /// Flow ratio used for bridges, relative to the normal flow. **OrcaSlicer and Creality Print.**
    static func bridgeFlow(_ ratio: Double) -> Self {
        .init(key: .bridgeFlow, value: String(ratio))
    }

    /// Density of bridge infill, as a whole-number percentage. **OrcaSlicer and Creality Print.**
    static func bridgeDensity(_ percent: Int) -> Self {
        .percent(.bridgeDensity, percent)
    }

    /// Extra flow applied while ironing, in addition to `ironingFlow`. **OrcaSlicer only.**
    static func ironingExpansion(_ millimeters: Double) -> Self {
        .init(key: .ironingExpansion, value: String(millimeters))
    }

    /// Whether Z-layer contouring ("Z anti-aliasing") is enabled — reduces the height of top-surface
    /// perimeters to more closely match the model's true edge height. **OrcaSlicer only.**
    static func zContouringEnabled(_ value: Bool) -> Self {
        .init(key: .zContouringEnabled, value: value ? "1" : "0")
    }

    /// Under Z-layer contouring, perimeters sloped less steeply than this angle (in degrees) have
    /// their height reduced to match the model's edge. `0` disables this. **OrcaSlicer only.**
    static func zContouringMinimizeWallHeightAngle(_ degrees: Double) -> Self {
        .init(key: .zContouringMinimizeWallHeightAngle, value: String(degrees))
    }

    /// Whether Z-layer contouring skips alternating its fill direction between layers.
    /// **OrcaSlicer only.**
    static func zContouringDisableAlternatingFillDirection(_ value: Bool) -> Self {
        .init(key: .zContouringDisableAlternatingFillDirection, value: value ? "1" : "0")
    }

    /// Minimum Z-layer height used by Z-layer contouring, in millimeters. Also controls the slicing
    /// plane. **OrcaSlicer only.**
    static func zContouringMinimumZHeight(_ millimeters: Double) -> Self {
        .init(key: .zContouringMinimumZHeight, value: String(millimeters))
    }

    /// Density of the top surface's solid infill, as a whole-number percentage. **OrcaSlicer only.**
    static func topSurfaceDensity(_ percent: Int) -> Self {
        .percent(.topSurfaceDensity, percent)
    }

    /// Density of the bottom surface's solid infill, as a whole-number percentage. **OrcaSlicer only.**
    static func bottomSurfaceDensity(_ percent: Int) -> Self {
        .percent(.bottomSurfaceDensity, percent)
    }

    /// Number of lines used per pass for infill patterns that support multi-line infill (1–10).
    /// **OrcaSlicer only.**
    static func fillMultiline(_ count: Int) -> Self {
        .init(key: .fillMultiline, value: String(count))
    }

    /// Angle of the first set of lattice infill elements in the Z direction, in degrees (zero is
    /// vertical). **OrcaSlicer only.**
    static func lateralLatticeAngle1(_ degrees: Double) -> Self {
        .init(key: .lateralLatticeAngle1, value: String(degrees))
    }

    /// Angle of the second set of lattice infill elements in the Z direction, in degrees (zero is
    /// vertical). **OrcaSlicer only.**
    static func lateralLatticeAngle2(_ degrees: Double) -> Self {
        .init(key: .lateralLatticeAngle2, value: String(degrees))
    }

    /// Angle of infill's angled lines, in degrees (60° produces a pure honeycomb). **OrcaSlicer only.**
    static func infillOverhangAngle(_ degrees: Double) -> Self {
        .init(key: .infillOverhangAngle, value: String(degrees))
    }

    /// Overhang angle used by lightning infill, in degrees. **OrcaSlicer only.**
    static func lightningOverhangAngle(_ degrees: Double) -> Self {
        .init(key: .lightningOverhangAngle, value: String(degrees))
    }

    /// Branch-pruning angle used by lightning infill, in degrees. **OrcaSlicer only.**
    static func lightningPruneAngle(_ degrees: Double) -> Self {
        .init(key: .lightningPruneAngle, value: String(degrees))
    }

    /// Branch-straightening angle used by lightning infill, in degrees. **OrcaSlicer only.**
    static func lightningStraighteningAngle(_ degrees: Double) -> Self {
        .init(key: .lightningStraighteningAngle, value: String(degrees))
    }

    /// Length of the infill anchor along the perimeter, in millimeters. The renamed successor to
    /// ``sparseInfillAnchor(_:)``. **OrcaSlicer and Creality Print.**
    ///
    /// Also accepts a percentage; use ``raw(_:_:)`` (e.g. `.raw(.infillAnchor, "50%")`) for that form.
    static func infillAnchor(_ millimeters: Double) -> Self {
        .init(key: .infillAnchor, value: String(millimeters))
    }

    /// Maximum length of the infill anchor along the perimeter, in millimeters. The renamed successor
    /// to ``sparseInfillAnchorMax(_:)``. **OrcaSlicer and Creality Print.**
    ///
    /// Also accepts a percentage; use ``raw(_:_:)`` (e.g. `.raw(.infillAnchorMax, "50%")`) for that form.
    static func infillAnchorMax(_ millimeters: Double) -> Self {
        .init(key: .infillAnchorMax, value: String(millimeters))
    }

    /// Distance the top surface is expanded outward to merge small gaps, in millimeters.
    /// **OrcaSlicer only.**
    static func topSurfaceExpansion(_ millimeters: Double) -> Self {
        .init(key: .topSurfaceExpansion, value: String(millimeters))
    }

    /// Margin used while computing top surface expansion, in millimeters. **OrcaSlicer only.**
    static func topSurfaceExpansionMargin(_ millimeters: Double) -> Self {
        .init(key: .topSurfaceExpansionMargin, value: String(millimeters))
    }

    /// Direction top surface expansion grows in. **OrcaSlicer only.**
    static func topSurfaceExpansionDirection(_ direction: TopSurfaceExpansionDirection) -> Self {
        .init(key: .topSurfaceExpansionDirection, value: direction.rawValue)
    }

    /// Whether solid infill direction rotates to align with the model rather than staying fixed.
    /// **OrcaSlicer only.**
    static func alignInfillDirectionToModel(_ value: Bool) -> Self {
        .init(key: .alignInfillDirectionToModel, value: value ? "1" : "0")
    }

    /// Inserts solid infill at specific layers. Accepts `"N"` (every Nth layer), `"N#K"` (K consecutive
    /// solid layers every N layers), or a comma-separated explicit layer list (e.g. `"1,7,9"`; layers
    /// are 1-based). **OrcaSlicer only.**
    static func extraSolidInfills(_ spec: String) -> Self {
        .init(key: .extraSolidInfills, value: spec)
    }

    /// Maximum combined layer height when combining sparse infill across multiple layers, in
    /// millimeters. **OrcaSlicer only.**
    ///
    /// Also accepts a percentage; use ``raw(_:_:)`` for that form.
    static func infillCombinationMaxLayerHeight(_ millimeters: Double) -> Self {
        .init(key: .infillCombinationMaxLayerHeight, value: String(millimeters))
    }

    /// Overlap between infill and the top/bottom solid shell, as a whole-number percentage.
    /// **OrcaSlicer and Creality Print.**
    static func topBottomInfillWallOverlap(_ percent: Int) -> Self {
        .percent(.topBottomInfillWallOverlap, percent)
    }

    /// Solid infill line direction, in degrees. **OrcaSlicer and Creality Print.**
    static func solidInfillDirection(_ degrees: Double) -> Self {
        .init(key: .solidInfillDirection, value: String(degrees))
    }

    /// Top solid layer line direction, in degrees. **OrcaSlicer only.**
    static func topLayerDirection(_ degrees: Double) -> Self {
        .init(key: .topLayerDirection, value: String(degrees))
    }

    /// Bottom solid layer line direction, in degrees. **OrcaSlicer only.**
    static func bottomLayerDirection(_ degrees: Double) -> Self {
        .init(key: .bottomLayerDirection, value: String(degrees))
    }

    /// Angle used for internal bridge infill, in degrees. **OrcaSlicer and Creality Print.**
    static func internalBridgeAngle(_ degrees: Double) -> Self {
        .init(key: .internalBridgeAngle, value: String(degrees))
    }
}

// MARK: - Creality Print extensions

/// Settings recognized by Creality Print but not vanilla Bambu Studio or OrcaSlicer.
public extension SlicerSetting {
    /// Number of walls supporting tree support branches, for the "tree" support style specifically.
    /// **Creality Print only.**
    static func treeSupportWallCountTree(_ count: Int) -> Self {
        .init(key: .treeSupportWallCountTree, value: String(count))
    }

    /// Support base pattern, for the "tree" support style specifically. **Creality Print only.**
    static func supportBasePatternTree(_ pattern: SupportBasePattern) -> Self {
        .init(key: .supportBasePatternTree, value: pattern.rawValue)
    }

    /// Minimum area a support interface region must have to be generated, in square millimeters.
    /// **Creality Print only.**
    static func supportInterfaceMinArea(_ squareMillimeters: Double) -> Self {
        .init(key: .supportInterfaceMinArea, value: String(squareMillimeters))
    }

    /// Whether organic tree supports are validated and automatically repaired if invalid.
    /// **Creality Print only.**
    static func treeSupportOrganicValidateRepair(_ value: Bool) -> Self {
        .init(key: .treeSupportOrganicValidateRepair, value: value ? "1" : "0")
    }

    /// Whether solid infill direction rotates a fixed amount between layers. **Creality Print only.**
    static func rotateSolidInfillDirection(_ value: Bool) -> Self {
        .init(key: .rotateSolidInfillDirection, value: value ? "1" : "0")
    }

    /// Whether the classic (pre-Arachne) overhang speed algorithm is used. **Creality Print only.**
    static func overhangSpeedClassic(_ value: Bool) -> Self {
        .init(key: .overhangSpeedClassic, value: value ? "1" : "0")
    }
}

internal extension Array where Element == SlicerSetting {
    /// Collapses to one value per key (last one wins on duplicates), matching how the underlying
    /// `model_settings.config` storage is keyed.
    var byKey: [SlicerSettingKey: String] {
        Dictionary(map { ($0.key, $0.value) }, uniquingKeysWith: { _, new in new })
    }
}

// MARK: - Accumulation and export

/// Accumulates declared slicer settings, keyed by the exact `Part` instance each was declared (or
/// re-declared, after packing) against — from anywhere in the tree, not just wherever a
/// postprocessing handler happens to be attached. Entries whose part never became a real 3MF object
/// (e.g. the original part behind a quantity>1 component, superseded by its numbered copies) are
/// simply unresolvable at write time and get filtered out rather than causing an error.
struct SlicerSettingsEntries: ResultElement {
    var entries: [(part: Part, settings: [SlicerSettingKey: String])]

    init() { entries = [] }
    init(combining elements: [SlicerSettingsEntries]) {
        entries = elements.flatMap(\.entries)
    }
}

/// Writes the platter's `Metadata/model_settings.config` sidecar from every slicer setting declared
/// anywhere in the tree, once per export. Safe to call redundantly — from `asComponent` on every
/// component that declares settings — since it checks `fileExists` before writing: whichever
/// registration runs first does the actual write, the rest see the file already there and no-op.
func writeBambuModelSettingsIfNeeded(using archive: ModelArchive) throws {
    let path = "Metadata/model_settings.config"
    guard !archive.fileExists(at: path) else { return }

    let entries = archive.resultElement(SlicerSettingsEntries.self).entries
    guard entries.contains(where: { archive.objectID(for: $0.part) != nil }) else { return }

    try archive.addFile(at: path, data: bambuModelSettingsConfig(for: entries, objectID: archive.objectID(for:)))
}

/// Builds a Bambu/Orca `model_settings.config` sidecar (per-object `<metadata key="..." value="..."/>`
/// entries under `<object id="...">`), keyed by each part's assigned 3MF object id. Parts whose id can't
/// be resolved (shouldn't happen for parts that were actually packed) are skipped rather than guessed at.
///
/// Entries are merged per resolved id rather than emitted one block per entry: `asComponent`'s own
/// declaration and `onPlatter`'s re-declaration against the final packed part both land in the
/// accumulator, and resolve to the *same* id whenever packing didn't rename or copy the part (e.g. the
/// common `quantity == 1`, `removingMaterials == false` case) — without merging, that produces
/// duplicate `<object>` blocks for the same id instead of one combined one.
func bambuModelSettingsConfig(
    for entries: [(part: Part, settings: [SlicerSettingKey: String])],
    objectID: (Part) -> Int?
) throws -> Data {
    var settingsByID: [Int: [SlicerSettingKey: String]] = [:]
    for (part, settings) in entries {
        guard let id = objectID(part) else { continue }
        settingsByID[id, default: [:]].merge(settings) { _, new in new }
    }

    let document = Document()
    let config = document.makeDocumentElement(name: "config")
    for id in settingsByID.keys.sorted() {
        let object = config.addElement("object")
        object[attribute: "id"] = String(id)
        for (key, value) in settingsByID[id]!.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            let metadata = object.addElement("metadata")
            metadata[attribute: "key"] = key.rawValue
            metadata[attribute: "value"] = value
        }
    }

    return try document.xmlData()
}
