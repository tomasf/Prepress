import Foundation

/// A print-setting option in PrusaSlicer's config vocabulary, identified by its underlying config key.
///
/// Every case here is a member of PrusaSlicer's `PrintObjectConfig` or `PrintRegionConfig`
/// (`PrintConfig.hpp`). That restriction matters: those two classes are the ones the slicer consults
/// per object, so a key outside them deserializes without complaint and is then quietly ignored at
/// slicing time.
///
/// You rarely name these directly: the ``SlicerSetting`` factories are slicer-agnostic and pick the
/// right key for each flavor themselves. This enum is here for ``SlicerSetting/raw(prusa:_:)``, for
/// options with no neutral factory.
///
/// - Warning: Unlike Bambu Studio, PrusaSlicer does **not** ignore keys it doesn't recognize. It
///   throws `UnknownOptionException` from a call site outside its importer's error handling, so a
///   single bad key makes the whole 3MF fail to open. If you reach for
///   `PrusaSettingKey(rawValue:)`, make sure the key really exists and really is per-object.
public enum PrusaSettingKey: String, Sendable {
    // Quality (PrintObjectConfig)
    case layerHeight = "layer_height"
    case sliceClosingRadius = "slice_closing_radius"
    case elephantFootCompensation = "elefant_foot_compensation"
    case xySizeCompensation = "xy_size_compensation"
    case seamPosition = "seam_position"
    case interfaceShells = "interface_shells"
    case perimeterGenerator = "perimeter_generator"
    case minFeatureSize = "min_feature_size"
    case minBeadWidth = "min_bead_width"

    // Adhesion (PrintObjectConfig)
    case brimType = "brim_type"
    case brimWidth = "brim_width"
    case brimSeparation = "brim_separation"
    case raftLayers = "raft_layers"
    case raftContactDistance = "raft_contact_distance"
    case raftExpansion = "raft_expansion"
    case raftFirstLayerDensity = "raft_first_layer_density"
    case raftFirstLayerExpansion = "raft_first_layer_expansion"

    // Support (PrintObjectConfig)
    case supportMaterial = "support_material"
    case supportMaterialAuto = "support_material_auto"
    case supportMaterialStyle = "support_material_style"
    case supportMaterialPattern = "support_material_pattern"
    case supportMaterialInterfacePattern = "support_material_interface_pattern"
    case supportMaterialThreshold = "support_material_threshold"
    case supportMaterialBuildplateOnly = "support_material_buildplate_only"
    case supportMaterialExtruder = "support_material_extruder"
    case supportMaterialInterfaceExtruder = "support_material_interface_extruder"
    case supportMaterialContactDistance = "support_material_contact_distance"
    case supportMaterialBottomContactDistance = "support_material_bottom_contact_distance"
    case supportMaterialSpacing = "support_material_spacing"
    case supportMaterialAngle = "support_material_angle"
    case supportMaterialInterfaceLayers = "support_material_interface_layers"
    case supportMaterialBottomInterfaceLayers = "support_material_bottom_interface_layers"
    case supportMaterialInterfaceSpacing = "support_material_interface_spacing"
    case supportMaterialXYSpacing = "support_material_xy_spacing"
    case supportMaterialWithSheath = "support_material_with_sheath"
    case supportMaterialClosingRadius = "support_material_closing_radius"
    case supportTreeAngle = "support_tree_angle"
    case supportTreeAngleSlow = "support_tree_angle_slow"
    case supportTreeBranchDiameter = "support_tree_branch_diameter"
    case supportTreeBranchDiameterAngle = "support_tree_branch_diameter_angle"
    case supportTreeBranchDistance = "support_tree_branch_distance"
    case supportTreeTipDiameter = "support_tree_tip_diameter"
    case supportTreeTopRate = "support_tree_top_rate"
    case dontSupportBridges = "dont_support_bridges"
    case thickBridges = "thick_bridges"

    // Ironing (PrintRegionConfig)
    case ironing
    case ironingType = "ironing_type"
    case ironingFlowrate = "ironing_flowrate"
    case ironingSpacing = "ironing_spacing"
    case ironingSpeed = "ironing_speed"

    // Strength / infill (PrintRegionConfig)
    case perimeters
    case topSolidLayers = "top_solid_layers"
    case bottomSolidLayers = "bottom_solid_layers"
    case topSolidMinThickness = "top_solid_min_thickness"
    case bottomSolidMinThickness = "bottom_solid_min_thickness"
    case fillDensity = "fill_density"
    case fillPattern = "fill_pattern"
    case topFillPattern = "top_fill_pattern"
    case bottomFillPattern = "bottom_fill_pattern"
    case fillAngle = "fill_angle"
    case infillAnchor = "infill_anchor"
    case infillAnchorMax = "infill_anchor_max"
    case infillEveryLayers = "infill_every_layers"
    case infillOverlap = "infill_overlap"
    case solidInfillBelowArea = "solid_infill_below_area"
    case solidInfillEveryLayers = "solid_infill_every_layers"
    case ensureVerticalShellThickness = "ensure_vertical_shell_thickness"
    case extraPerimeters = "extra_perimeters"
    case extraPerimetersOnOverhangs = "extra_perimeters_on_overhangs"
    case externalPerimetersFirst = "external_perimeters_first"
    case thinWalls = "thin_walls"
    case overhangs
    case gapFillEnabled = "gap_fill_enabled"
    case bridgeAngle = "bridge_angle"
    case bridgeFlowRatio = "bridge_flow_ratio"
    case fuzzySkin = "fuzzy_skin"
    case fuzzySkinThickness = "fuzzy_skin_thickness"
    case fuzzySkinPointDistance = "fuzzy_skin_point_dist"

    // Multi-material
    /// The extruder to use unless a more specific one is set. PrusaSlicer expands a per-object
    /// `extruder` into the perimeter, infill and solid infill extruders while normalizing the config.
    case extruder
    case perimeterExtruder = "perimeter_extruder"
    case infillExtruder = "infill_extruder"
    case solidInfillExtruder = "solid_infill_extruder"
    case wipeIntoInfill = "wipe_into_infill"
    case wipeIntoObjects = "wipe_into_objects"
}
