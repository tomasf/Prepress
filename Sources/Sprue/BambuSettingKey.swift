import Foundation

/// A print-setting option in Bambu Studio's config vocabulary, identified by its underlying config key.
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
/// You rarely name these directly: the ``SlicerSetting`` factories are slicer-agnostic and pick the
/// right key for each flavor themselves. This enum is here for ``SlicerSetting/raw(bambu:_:)``, for
/// options with no neutral factory.
///
/// Since this is a plain `String`-backed enum, it's `RawRepresentable`, so a key not listed here can
/// still be used via `BambuSettingKey(rawValue: "some_other_key")`.
public enum BambuSettingKey: String, Sendable {
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
