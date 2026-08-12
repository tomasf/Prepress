import Foundation
import Cadova

// MARK: - Enumerated setting values

/// Infill/surface fill pattern.
///
/// Cases are named for the pattern itself, and each one knows how its slicer flavors spell it. A
/// pattern that only one of them has is simply left out of the other's config rather than
/// approximated with something similar.
///
/// Not every case is valid for every pattern-typed setting, and the split runs both ways.
/// ``SlicerSetting/topSurfacePattern(_:)``, ``SlicerSetting/bottomSurfacePattern(_:)`` and
/// ``SlicerSetting/internalSolidInfillPattern(_:)`` accept only `concentric`, `rectilinear`,
/// `monotonic`, `monotonicLine`, `alignedRectilinear`, `hilbertCurve`, `archimedeanChords` and
/// `octagramSpiral`. Conversely `monotonic` and `monotonicLine` are surface patterns only — neither
/// slicer family accepts them for sparse infill, so don't pass them to
/// ``SlicerSetting/infillPattern(_:)``. Every remaining case is for sparse infill alone.
public enum InfillPattern: Sendable {
    case concentric
    case rectilinear
    case grid
    case line
    case cubic
    case triangles
    /// Bambu Studio and its forks only.
    case triHexagon
    case gyroid
    case honeycomb
    case adaptiveCubic
    case alignedRectilinear
    case honeycomb3D
    case hilbertCurve
    case archimedeanChords
    case octagramSpiral
    case supportCubic
    case lightning
    /// Bambu Studio and its forks only.
    case crossHatch
    /// Bambu Studio and OrcaSlicer only. Creality Print has this pattern but spells it differently
    /// and doesn't accept Bambu's spelling, so it's ignored there.
    case zigzag
    /// Bambu Studio and OrcaSlicer only. Creality Print has this pattern but spells it differently
    /// and doesn't accept Bambu's spelling, so it's ignored there.
    case crossZag
    /// Bambu Studio and OrcaSlicer only. Creality Print has this pattern but spells it differently
    /// and doesn't accept Bambu's spelling, so it's ignored there.
    case lockedZag
    case monotonic
    case monotonicLine
    /// PrusaSlicer only.
    case stars

    /// - Note: Bambu's raw value for `rectilinear` is, confusingly, `"zig-zag"` — a legacy name from
    ///   before the pattern was renamed in the UI. The distinct `zigzag` case (no hyphen) is the
    ///   actual "Zig Zag" pattern; the two are not aliases of each other.
    var bambuValue: String? {
        switch self {
        case .concentric: "concentric"
        case .rectilinear: "zig-zag"
        case .grid: "grid"
        case .line: "line"
        case .cubic: "cubic"
        case .triangles: "triangles"
        case .triHexagon: "tri-hexagon"
        case .gyroid: "gyroid"
        case .honeycomb: "honeycomb"
        case .adaptiveCubic: "adaptivecubic"
        case .alignedRectilinear: "alignedrectilinear"
        case .honeycomb3D: "3dhoneycomb"
        case .hilbertCurve: "hilbertcurve"
        case .archimedeanChords: "archimedeanchords"
        case .octagramSpiral: "octagramspiral"
        case .supportCubic: "supportcubic"
        case .lightning: "lightning"
        case .crossHatch: "crosshatch"
        case .zigzag: "zigzag"
        case .crossZag: "crosszag"
        case .lockedZag: "lockedzag"
        case .monotonic: "monotonic"
        case .monotonicLine: "monotonicline"
        case .stars: nil
        }
    }

    var prusaValue: String? {
        switch self {
        case .concentric: "concentric"
        case .rectilinear: "rectilinear"
        case .grid: "grid"
        case .line: "line"
        case .cubic: "cubic"
        case .triangles: "triangles"
        case .triHexagon: nil
        case .gyroid: "gyroid"
        case .honeycomb: "honeycomb"
        case .adaptiveCubic: "adaptivecubic"
        case .alignedRectilinear: "alignedrectilinear"
        case .honeycomb3D: "3dhoneycomb"
        case .hilbertCurve: "hilbertcurve"
        case .archimedeanChords: "archimedeanchords"
        case .octagramSpiral: "octagramspiral"
        case .supportCubic: "supportcubic"
        case .lightning: "lightning"
        case .crossHatch: nil
        case .zigzag: "zigzag"
        case .crossZag: nil
        case .lockedZag: nil
        case .monotonic: "monotonic"
        case .monotonicLine: "monotoniclines"
        case .stars: "stars"
        }
    }
}

/// Seam positioning strategy.
public enum SeamPosition: Sendable {
    case nearest, aligned, back, random

    var bambuValue: String? {
        switch self {
        case .nearest: "nearest"
        case .aligned: "aligned"
        case .back: "back"
        case .random: "random"
        }
    }

    /// PrusaSlicer calls the rearmost position `rear` rather than `back`.
    var prusaValue: String? {
        switch self {
        case .nearest: "nearest"
        case .aligned: "aligned"
        case .back: "rear"
        case .random: "random"
        }
    }
}

/// Ironing mode applied to top surfaces.
///
/// PrusaSlicer splits this in two: an "Enable ironing" checkbox turns the feature on, and "Ironing
/// Type" selects the surfaces. ``SlicerSetting/ironingType(_:)`` writes both, so `noIroning` disables
/// ironing there rather than selecting a "none" mode it doesn't have.
public enum IroningType: Sendable {
    /// Understood by every slicer, but reached differently: PrusaSlicer has no "none" mode, so this
    /// clears its "Enable ironing" checkbox instead.
    case noIroning
    case top
    case topmost
    case solid

    var bambuValue: String? {
        switch self {
        case .noIroning: "no ironing"
        case .top: "top"
        case .topmost: "topmost"
        case .solid: "solid"
        }
    }

    var prusaValue: String? {
        switch self {
        case .noIroning: nil
        case .top: "top"
        case .topmost: "topmost"
        case .solid: "solid"
        }
    }
}

/// Support generation algorithm.
///
/// Bambu Studio expresses the algorithm and whether it's placed automatically in one option;
/// PrusaSlicer keeps them apart, as "Style" and the "Auto generated supports" checkbox.
/// ``SlicerSetting/supportType(_:)`` writes both on the PrusaSlicer side.
public enum SupportType: Sendable {
    case normalAuto
    case treeAuto
    case normalManual
    case treeManual

    var bambuValue: String? {
        switch self {
        case .normalAuto: "normal(auto)"
        case .treeAuto: "tree(auto)"
        case .normalManual: "normal(manual)"
        case .treeManual: "tree(manual)"
        }
    }

    var isAutomatic: Bool {
        switch self {
        case .normalAuto, .treeAuto: true
        case .normalManual, .treeManual: false
        }
    }

    var prusaStyleValue: String? {
        switch self {
        case .normalAuto, .normalManual: "grid"
        case .treeAuto, .treeManual: "organic"
        }
    }
}

/// Support structure style.
public enum SupportStyle: Sendable {
    /// Bambu Studio and its forks only.
    case `default`
    case grid
    case snug
    /// PrusaSlicer has only one tree support, so it gets "Organic" there.
    case treeSlim
    /// PrusaSlicer has only one tree support, so it gets "Organic" there.
    case treeStrong
    /// PrusaSlicer has only one tree support, so it gets "Organic" there.
    case treeHybrid
    /// OrcaSlicer and Creality Print renamed this style and don't accept Bambu Studio's spelling of
    /// it, so it applies in Bambu Studio and PrusaSlicer but is ignored by those two forks. The other
    /// three tree styles are understood everywhere.
    case treeOrganic

    var bambuValue: String? {
        switch self {
        case .default: "default"
        case .grid: "grid"
        case .snug: "snug"
        case .treeSlim: "tree_slim"
        case .treeStrong: "tree_strong"
        case .treeHybrid: "tree_hybrid"
        case .treeOrganic: "tree_organic"
        }
    }

    /// PrusaSlicer offers only Grid, Snug and Organic, so Bambu's three tuned tree variants all map to
    /// Organic — its one tree support — alongside `treeOrganic` itself.
    var prusaValue: String? {
        switch self {
        case .default: nil
        case .grid: "grid"
        case .snug: "snug"
        case .treeSlim, .treeStrong, .treeHybrid, .treeOrganic: "organic"
        }
    }
}

/// Support base (interface/raft-like) fill pattern.
public enum SupportBasePattern: Sendable {
    case `default`
    case rectilinear
    case rectilinearGrid
    case honeycomb
    /// Bambu Studio and its forks only.
    case lightning
    /// Bambu Studio and its forks only.
    case hollow

    var bambuValue: String? {
        switch self {
        case .default: "default"
        case .rectilinear: "rectilinear"
        case .rectilinearGrid: "rectilinear-grid"
        case .honeycomb: "honeycomb"
        case .lightning: "lightning"
        case .hollow: "hollow"
        }
    }

    var prusaValue: String? {
        switch self {
        case .default, .lightning, .hollow: nil
        case .rectilinear: "rectilinear"
        case .rectilinearGrid: "rectilinear-grid"
        case .honeycomb: "honeycomb"
        }
    }
}

/// Brim generation strategy.
public enum BrimType: Sendable {
    /// Bambu Studio and its forks only.
    case auto
    /// Bambu Studio and its forks only.
    case painted
    case outerOnly
    case innerOnly
    case outerAndInner
    case none

    var bambuValue: String? {
        switch self {
        case .auto: "auto_brim"
        case .painted: "brim_ears"
        case .outerOnly: "outer_only"
        case .innerOnly: "inner_only"
        case .outerAndInner: "outer_and_inner"
        case .none: "no_brim"
        }
    }

    var prusaValue: String? {
        switch self {
        case .auto, .painted: nil
        case .outerOnly: "outer_only"
        case .innerOnly: "inner_only"
        case .outerAndInner: "outer_and_inner"
        case .none: "no_brim"
        }
    }
}

/// Wall printing order.
///
/// PrusaSlicer has no ordering option of its own — only a boolean for whether the external perimeter
/// comes first — so `innerOuterInner` has no equivalent there and is left out of its config.
public enum WallSequence: Sendable {
    case innerOuter
    case outerInner
    /// Bambu Studio and its forks only.
    case innerOuterInner

    var bambuValue: String? {
        switch self {
        case .innerOuter: "inner wall/outer wall"
        case .outerInner: "outer wall/inner wall"
        case .innerOuterInner: "inner-outer-inner wall"
        }
    }

    var prusaExternalPerimetersFirstValue: String? {
        switch self {
        case .innerOuter: "0"
        case .outerInner: "1"
        case .innerOuterInner: nil
        }
    }
}

/// Direction top-surface expansion grows in. **OrcaSlicer only.**
public enum TopSurfaceExpansionDirection: String, Sendable {
    case inwardAndOutward = "inward_and_outward"
    case inward
    case outward
}

// MARK: - Setting values

/// A typed, slicer-agnostic print setting, ready to be lowered into the per-object config sidecars
/// Sprue embeds in its 3MF output.
///
/// Construct these through the static factory methods below (e.g. `.enableSupport(true)`,
/// `.infillDensity(15)`) rather than by hand, so each setting's value can only be constructed with
/// the Swift type the option actually expects.
///
/// Each setting carries its own lowering for both supported config flavors: Bambu Studio's
/// `model_settings.config` (also read by OrcaSlicer, Creality Print and the other Bambu-derived
/// vendor slicers) and PrusaSlicer's `Slic3r_PE_model.config` (also read by SuperSlicer). Either side
/// may be empty — many options exist in only one of them, and a setting with no equivalent in a
/// flavor contributes nothing to that flavor's file rather than being approximated.
///
/// A single setting can also lower to *several* keys in one flavor, either because the option is
/// grouped differently there (``supportType(_:)`` becomes two PrusaSlicer options) or because the
/// grouped factories in `SlicerSettingGroups.swift` (e.g. `.infill(.gyroid, density: 20)`) carry
/// several options in one value. That's why each side is a dictionary rather than a lone pair.
///
/// ## Slicer support
///
/// A setting whose documentation carries no slicer note is understood by every slicer Sprue writes
/// for: Bambu Studio, OrcaSlicer, Creality Print and the other Bambu-derived vendor slicers,
/// PrusaSlicer, and SuperSlicer. Anything narrower says so in bold at the end of its description:
///
/// - **Bambu Studio and its forks only.** — ignored by PrusaSlicer and SuperSlicer.
/// - **OrcaSlicer only.** / **OrcaSlicer and Creality Print.** / **Creality Print only.** — ignored
///   by everything else, vanilla Bambu Studio included.
///
/// "Ignored" is literal and harmless: the option is simply left out of that slicer's config file, so
/// the object keeps whatever the loaded print profile specifies for it. Nothing fails to open, and
/// nothing is approximated with a neighbouring option that means something subtly different.
///
/// Sprue's own names are slicer-agnostic, so they can't match both vocabularies at once. Each setting
/// therefore records what the slicers call it in their own UIs ("Shown as …"), for finding the same
/// option by hand. Where a name already matches everywhere, there's nothing to record and no note.
///
/// A setting can be universal while some of its *values* aren't — PrusaSlicer has no `crossHatch`
/// infill, for instance. Those exceptions are marked case by case on the value enums, and behave the
/// same way: an unsupported value drops the option for that slicer rather than substituting a guess.
public struct SlicerSetting: Sendable {
    /// Keys for Bambu Studio's `model_settings.config`. May be empty.
    let bambu: [BambuSettingKey: String]
    /// Keys for PrusaSlicer's `Slic3r_PE_model.config`. May be empty.
    let prusa: [PrusaSettingKey: String]

    init(bambu: [BambuSettingKey: String] = [:], prusa: [PrusaSettingKey: String] = [:]) {
        self.bambu = bambu
        self.prusa = prusa
    }
}

internal extension SlicerSetting {
    /// A single pair, or nothing at all when either half is absent. Both "this flavor has no such
    /// option" and "this parameter wasn't specified" collapse to the same thing: don't write it.
    static func pair<Key: Hashable>(_ key: Key?, _ value: String?) -> [Key: String] {
        guard let key, let value else { return [:] }
        return [key: value]
    }

    static func number<Value: LosslessStringConvertible>(_ value: Value?) -> String? {
        value.map { String($0) }
    }

    static func percent(_ value: Int?) -> String? {
        value.map { "\($0)%" }
    }

    /// Both config formats express angles as a bare number of degrees, with no unit suffix.
    static func degrees(_ angle: Angle?) -> String? {
        angle.map { String($0.degrees) }
    }

    /// Degrees for the options both slicers declare as integers, rounded so the value doesn't arrive
    /// with a fractional part their integer parsers would have to discard.
    static func wholeDegrees(_ angle: Angle?) -> String? {
        angle.map { String(Int($0.degrees.rounded())) }
    }

    /// Both slicers write booleans as `1`/`0`, not `true`/`false`.
    static func flag(_ value: Bool?) -> String? {
        value.map { $0 ? "1" : "0" }
    }
}

private extension SlicerSetting {
    /// One key per flavor sharing a value — the common case. A `nil` key means that flavor has no
    /// equivalent option.
    init(bambu bambuKey: BambuSettingKey?, prusa prusaKey: PrusaSettingKey?, _ value: String?) {
        self.init(bambu: Self.pair(bambuKey, value), prusa: Self.pair(prusaKey, value))
    }

    /// One key per flavor with values that differ — used where the two vocabularies diverge.
    init(
        bambu bambuKey: BambuSettingKey?, _ bambuValue: String?,
        prusa prusaKey: PrusaSettingKey?, _ prusaValue: String?
    ) {
        self.init(bambu: Self.pair(bambuKey, bambuValue), prusa: Self.pair(prusaKey, prusaValue))
    }

    /// A setting only Bambu Studio and its forks understand.
    init(bambuOnly key: BambuSettingKey, _ value: String?) {
        self.init(bambu: Self.pair(key, value))
    }
}

public extension SlicerSetting {
    // MARK: Quality

    /// Layer height, in millimeters.
    static func layerHeight(_ millimeters: Double) -> Self {
        .init(bambu: .layerHeight, prusa: .layerHeight, number(millimeters))
    }

    /// Wall printing order.
    ///
    /// PrusaSlicer only distinguishes inner-first from outer-first, so ``WallSequence/innerOuterInner``
    /// is written for Bambu Studio and its forks alone.
    ///
    /// Shown as "Order of walls" in Bambu Studio and "Walls printing order" in its forks. PrusaSlicer has no ordering option, only the "External perimeters first" checkbox.
    static func wallSequence(_ sequence: WallSequence) -> Self {
        .init(
            bambu: .wallSequence, sequence.bambuValue,
            prusa: .externalPerimetersFirst, sequence.prusaExternalPerimetersFirstValue
        )
    }

    /// Seam positioning strategy.
    static func seamPosition(_ position: SeamPosition) -> Self {
        .init(bambu: .seamPosition, position.bambuValue, prusa: .seamPosition, position.prusaValue)
    }

    /// Extra distance to move the seam away from the model, as a percentage of the nozzle diameter.
    /// **Bambu Studio and its forks only.**
    static func seamGap(_ percent: Int) -> Self {
        .init(bambuOnly: .seamGap, Self.percent(percent))
    }

    /// Speed of the wipe move after retraction, as a percentage of the outer wall speed.
    /// **Bambu Studio and its forks only.**
    static func wipeSpeed(_ percent: Int) -> Self {
        .init(bambuOnly: .wipeSpeed, Self.percent(percent))
    }

    /// Maximum radius of gaps closed during slicing, in millimeters.
    ///
    /// Shown as "Slice gap closing radius" in every supported slicer.
    static func sliceClosingRadius(_ millimeters: Double) -> Self {
        .init(bambu: .sliceClosingRadius, prusa: .sliceClosingRadius, number(millimeters))
    }

    /// Slicing resolution, in millimeters. **Bambu Studio and its forks only.**
    ///
    /// PrusaSlicer has a `resolution` option, but only as a global print setting — it can't be varied
    /// per object, so there's nothing to write into its per-object config.
    static func resolution(_ millimeters: Double) -> Self {
        .init(bambuOnly: .resolution, number(millimeters))
    }

    /// XY compensation applied to holes, in millimeters (positive values enlarge holes).
    /// **Bambu Studio and its forks only.**
    ///
    /// PrusaSlicer has no separate hole compensation. Its single "XY Size Compensation" applies to
    /// everything, and is written by ``contourCompensation(_:)`` instead.
    ///
    /// Shown as "X-Y hole compensation" in Bambu Studio and its forks.
    static func holeCompensation(_ millimeters: Double) -> Self {
        .init(bambuOnly: .xyHoleCompensation, number(millimeters))
    }

    /// XY compensation applied to outer contours, in millimeters (positive values shrink the part).
    ///
    /// Shown as "X-Y contour compensation" in Bambu Studio and its forks, and "XY Size Compensation" in PrusaSlicer.
    static func contourCompensation(_ millimeters: Double) -> Self {
        .init(bambu: .xyContourCompensation, prusa: .xySizeCompensation, number(millimeters))
    }

    /// Elephant foot compensation, in millimeters.
    static func elephantFootCompensation(_ millimeters: Double) -> Self {
        .init(bambu: .elephantFootCompensation, prusa: .elephantFootCompensation, number(millimeters))
    }

    /// Whether to use precise Z height, ignoring the printer's layer height rounding.
    /// **Bambu Studio and its forks only.**
    ///
    /// Shown as "Precise Z height" in Bambu Studio and its forks.
    static func preciseZHeight(_ value: Bool) -> Self {
        .init(bambuOnly: .preciseZHeight, flag(value))
    }

    // MARK: Support & adhesion

    /// Brim generation strategy.
    ///
    /// ``BrimType/auto`` and ``BrimType/painted`` have no PrusaSlicer equivalent and are written for
    /// Bambu Studio and its forks alone; the remaining cases are understood everywhere.
    static func brimType(_ type: BrimType) -> Self {
        .init(bambu: .brimType, type.bambuValue, prusa: .brimType, type.prusaValue)
    }

    /// Brim width, in millimeters.
    static func brimWidth(_ millimeters: Double) -> Self {
        .init(bambu: .brimWidth, prusa: .brimWidth, number(millimeters))
    }

    /// Gap left between the brim and the object, in millimeters.
    ///
    /// Shown as "Brim-object gap" in Bambu Studio and its forks, and "Brim separation gap" in PrusaSlicer.
    static func brimObjectGap(_ millimeters: Double) -> Self {
        .init(bambu: .brimObjectGap, prusa: .brimSeparation, number(millimeters))
    }

    /// Whether support material is generated for this object.
    ///
    /// Shown as "Enable support" in Bambu Studio and its forks, and "Generate support material" in PrusaSlicer.
    static func enableSupport(_ value: Bool) -> Self {
        .init(bambu: .enableSupport, prusa: .supportMaterial, flag(value))
    }

    /// Support generation algorithm.
    ///
    /// Shown as "Type" under Support in Bambu Studio and its forks. PrusaSlicer splits it into "Style" and the "Auto generated supports" checkbox.
    static func supportType(_ type: SupportType) -> Self {
        .init(
            bambu: Self.pair(.supportType, type.bambuValue),
            prusa: Self.pair(.supportMaterialStyle, type.prusaStyleValue)
                .merging(Self.pair(.supportMaterialAuto, flag(type.isAutomatic))) { current, _ in current }
        )
    }

    /// Overhang threshold angle, measured from vertical, that triggers support generation.
    ///
    /// Shown as "Threshold angle" in Bambu Studio and its forks, and "Overhang threshold" in PrusaSlicer.
    static func supportThresholdAngle(_ angle: Angle) -> Self {
        .init(bambu: .supportThresholdAngle, prusa: .supportMaterialThreshold, wholeDegrees(angle))
    }

    /// Whether support is only generated where it touches the build plate.
    ///
    /// Shown as "On build plate only" in Bambu Studio and its forks, and "Support on build plate only" in PrusaSlicer.
    static func supportOnBuildPlateOnly(_ value: Bool) -> Self {
        .init(bambu: .supportOnBuildPlateOnly, prusa: .supportMaterialBuildplateOnly, flag(value))
    }

    /// The (1-based) extruder used to print support.
    ///
    /// Shown as "Support/raft base" in Bambu Studio and its forks, and "Support material/raft/skirt extruder" in PrusaSlicer.
    static func supportFilament(_ number: Int) -> Self {
        .init(bambu: .supportFilament, prusa: .supportMaterialExtruder, Self.number(number))
    }

    /// The (1-based) extruder used to print the support interface.
    ///
    /// Shown as "Support/raft interface" in Bambu Studio and its forks, and "Support material/raft interface extruder" in PrusaSlicer.
    static func supportInterfaceFilament(_ number: Int) -> Self {
        .init(bambu: .supportInterfaceFilament, prusa: .supportMaterialInterfaceExtruder, Self.number(number))
    }

    /// Horizontal expansion applied to support relative to the model, in millimeters.
    /// **Bambu Studio and its forks only.**
    ///
    /// Shown as "Normal Support expansion" in Bambu Studio and Creality Print, "Normal support expansion" in OrcaSlicer.
    static func supportExpansion(_ millimeters: Double) -> Self {
        .init(bambuOnly: .supportExpansion, number(millimeters))
    }

    /// Support structure style.
    ///
    /// PrusaSlicer has a coarser vocabulary here: Bambu's three tuned tree variants all become its
    /// single `tree`, and ``SupportStyle/default`` is written for Bambu Studio and its forks alone.
    ///
    /// Shown as "Style" in every supported slicer.
    static func supportStyle(_ style: SupportStyle) -> Self {
        .init(bambu: .supportStyle, style.bambuValue, prusa: .supportMaterialStyle, style.prusaValue)
    }

    /// Tree support branch angle.
    ///
    /// Shown as "Branch angle" in Bambu Studio, "Tree support branch angle" in its forks, and "Maximum Branch Angle" in PrusaSlicer.
    static func treeSupportBranchAngle(_ angle: Angle) -> Self {
        .init(bambu: .treeSupportBranchAngle, prusa: .supportTreeAngle, degrees(angle))
    }

    /// Number of walls supporting the branches of a tree support.
    /// **Bambu Studio and its forks only.**
    ///
    /// Shown as "Support wall loops" in Bambu Studio and OrcaSlicer, "Support wall loops(Normal)" in Creality Print.
    static func treeSupportWallCount(_ count: Int) -> Self {
        .init(bambuOnly: .treeSupportWallCount, number(count))
    }

    /// Angle at which tree support branches increase in diameter.
    ///
    /// Shown as "Branch diameter angle" in every supported slicer.
    static func treeSupportBranchDiameterAngle(_ angle: Angle) -> Self {
        .init(bambu: .treeSupportBranchDiameterAngle, prusa: .supportTreeBranchDiameterAngle, degrees(angle))
    }

    /// Vertical gap between the top of support and the model above it, in millimeters.
    ///
    /// Shown as "Top Z distance" in Bambu Studio and its forks, and "Top contact Z distance" in PrusaSlicer.
    static func supportTopZDistance(_ millimeters: Double) -> Self {
        .init(bambu: .supportTopZDistance, prusa: .supportMaterialContactDistance, number(millimeters))
    }

    /// Vertical gap between the model and the support below it, in millimeters.
    ///
    /// Shown as "Bottom Z distance" in Bambu Studio and its forks, and "Bottom contact Z distance" in PrusaSlicer.
    static func supportBottomZDistance(_ millimeters: Double) -> Self {
        .init(bambu: .supportBottomZDistance, prusa: .supportMaterialBottomContactDistance, number(millimeters))
    }

    /// Support base (interface/raft-like) fill pattern.
    ///
    /// ``SupportBasePattern/default``, ``SupportBasePattern/lightning`` and
    /// ``SupportBasePattern/hollow`` are written for Bambu Studio and its forks alone.
    ///
    /// Shown as "Base pattern" in Bambu Studio and OrcaSlicer, "Base pattern(Normal)" in Creality Print, and "Pattern" under Support material in PrusaSlicer.
    static func supportBasePattern(_ pattern: SupportBasePattern) -> Self {
        .init(bambu: .supportBasePattern, pattern.bambuValue, prusa: .supportMaterialPattern, pattern.prusaValue)
    }

    /// Spacing between lines of the support base pattern, in millimeters.
    ///
    /// Shown as "Base pattern spacing" in Bambu Studio and its forks, and "Pattern spacing" in PrusaSlicer.
    static func supportBasePatternSpacing(_ millimeters: Double) -> Self {
        .init(bambu: .supportBasePatternSpacing, prusa: .supportMaterialSpacing, number(millimeters))
    }

    /// Number of solid support interface layers, at the top of the support.
    ///
    /// Shown as "Top interface layers" in every supported slicer.
    static func supportInterfaceTopLayers(_ count: Int) -> Self {
        .init(bambu: .supportInterfaceTopLayers, prusa: .supportMaterialInterfaceLayers, number(count))
    }

    /// Number of solid support interface layers, at the bottom of the support.
    ///
    /// Shown as "Bottom interface layers" in every supported slicer.
    static func supportInterfaceBottomLayers(_ count: Int) -> Self {
        .init(bambu: .supportInterfaceBottomLayers, prusa: .supportMaterialBottomInterfaceLayers, number(count))
    }

    /// Spacing between lines of the support interface, in millimeters.
    ///
    /// Shown as "Top interface spacing" in Bambu Studio and its forks, and "Interface pattern spacing" in PrusaSlicer.
    static func supportInterfaceSpacing(_ millimeters: Double) -> Self {
        .init(bambu: .supportInterfaceSpacing, prusa: .supportMaterialInterfaceSpacing, number(millimeters))
    }

    /// Spacing between lines of the bottom support interface, in millimeters.
    /// **Bambu Studio and its forks only.**
    ///
    /// PrusaSlicer uses one spacing for both interfaces; ``supportInterfaceSpacing(_:)`` sets it.
    ///
    /// Shown as "Bottom interface spacing" in Bambu Studio and its forks.
    static func supportBottomInterfaceSpacing(_ millimeters: Double) -> Self {
        .init(bambuOnly: .supportBottomInterfaceSpacing, number(millimeters))
    }

    /// Horizontal clearance between support and the model, in millimeters.
    static func supportObjectXYDistance(_ millimeters: Double) -> Self {
        .init(bambu: .supportObjectXYDistance, prusa: .supportMaterialXYSpacing, number(millimeters))
    }

    /// Whether to disable support generation under bridges.
    ///
    /// Shown as "Don't support bridges" in every supported slicer.
    static func bridgeNoSupport(_ value: Bool) -> Self {
        .init(bambu: .bridgeNoSupport, prusa: .dontSupportBridges, flag(value))
    }

    /// Maximum bridge length printed without support, in millimeters.
    /// **Bambu Studio and its forks only.**
    static func maxBridgeLength(_ millimeters: Double) -> Self {
        .init(bambuOnly: .maxBridgeLength, number(millimeters))
    }

    /// Whether support is only generated for critical (large, unsupported) regions.
    /// **Bambu Studio and its forks only.**
    static func supportCriticalRegionsOnly(_ value: Bool) -> Self {
        .init(bambuOnly: .supportCriticalRegionsOnly, flag(value))
    }

    /// Whether small overhang areas are excluded from support generation.
    /// **Bambu Studio and its forks only.**
    ///
    /// Shown as "Remove small overhangs" in Bambu Studio and Creality Print, "Ignore small overhangs" in OrcaSlicer.
    static func supportRemoveSmallOverhang(_ value: Bool) -> Self {
        .init(bambuOnly: .supportRemoveSmallOverhang, flag(value))
    }

    /// Extra gap between the object's first layer and support, in millimeters.
    /// **Bambu Studio and its forks only.**
    static func supportObjectFirstLayerGap(_ millimeters: Double) -> Self {
        .init(bambuOnly: .supportObjectFirstLayerGap, number(millimeters))
    }

    // MARK: Ironing

    /// Ironing mode applied to top surfaces.
    ///
    /// On the PrusaSlicer side this also writes the separate `ironing` flag that turns the feature on
    /// or off, since it has no "no ironing" mode of its own.
    ///
    /// Shown as "Ironing type" in Bambu Studio and its forks. PrusaSlicer splits it into "Ironing Type" and the "Enable ironing" checkbox.
    static func ironingType(_ type: IroningType) -> Self {
        .init(
            bambu: Self.pair(.ironingType, type.bambuValue),
            prusa: Self.pair(.ironingType, type.prusaValue)
                .merging(Self.pair(.ironing, flag(type != .noIroning))) { current, _ in current }
        )
    }

    /// Flow rate ratio used while ironing, as a whole-number percentage.
    ///
    /// Shown as "Ironing flow" in Bambu Studio and its forks, and "Flow rate" in PrusaSlicer.
    static func ironingFlow(_ percent: Int) -> Self {
        .init(bambu: .ironingFlow, prusa: .ironingFlowrate, Self.percent(percent))
    }

    /// Spacing between ironing passes, in millimeters.
    ///
    /// Shown as "Ironing line spacing" in Bambu Studio and its forks, and "Spacing between ironing passes" in PrusaSlicer.
    static func ironingSpacing(_ millimeters: Double) -> Self {
        .init(bambu: .ironingSpacing, prusa: .ironingSpacing, number(millimeters))
    }

    /// Distance ironing is inset from the perimeter, in millimeters.
    /// **Bambu Studio and OrcaSlicer only.**
    ///
    /// Shown as "Ironing inset" in Bambu Studio and OrcaSlicer.
    static func ironingInset(_ millimeters: Double) -> Self {
        .init(bambuOnly: .ironingInset, number(millimeters))
    }

    /// Ironing speed, in millimeters per second.
    ///
    /// Shown as "Ironing speed" in Bambu Studio and its forks, and "Ironing" in PrusaSlicer.
    static func ironingSpeed(_ millimetersPerSecond: Double) -> Self {
        .init(bambu: .ironingSpeed, prusa: .ironingSpeed, number(millimetersPerSecond))
    }

    /// Ironing line direction.
    /// **Bambu Studio and its forks only.**
    ///
    /// Shown as "ironing direction" in Bambu Studio and "Ironing angle" in its forks, which renamed
    /// the option but still accept Bambu's spelling and translate it when the file is loaded.
    static func ironingDirection(_ angle: Angle) -> Self {
        .init(bambuOnly: .ironingDirection, degrees(angle))
    }

    // MARK: Strength / infill

    /// Number of perimeter walls.
    ///
    /// Shown as "Wall loops" in Bambu Studio and its forks, and "Perimeters" in PrusaSlicer.
    static func wallCount(_ count: Int) -> Self {
        .init(bambu: .wallLoops, prusa: .perimeters, number(count))
    }

    /// Number of solid top layers.
    ///
    /// Shown as "Top shell layers" in Bambu Studio and its forks, and "Top solid layers" in PrusaSlicer.
    static func topShellLayers(_ count: Int) -> Self {
        .init(bambu: .topShellLayers, prusa: .topSolidLayers, number(count))
    }

    /// Minimum thickness of solid top shell, in millimeters (adds layers beyond `topShellLayers` if needed).
    ///
    /// Shown as "Top shell thickness" in Bambu Studio and its forks, and "Minimum top shell thickness" in PrusaSlicer.
    static func topShellThickness(_ millimeters: Double) -> Self {
        .init(bambu: .topShellThickness, prusa: .topSolidMinThickness, number(millimeters))
    }

    /// Number of solid bottom layers.
    ///
    /// Shown as "Bottom shell layers" in Bambu Studio and its forks, and "Bottom solid layers" in PrusaSlicer.
    static func bottomShellLayers(_ count: Int) -> Self {
        .init(bambu: .bottomShellLayers, prusa: .bottomSolidLayers, number(count))
    }

    /// Minimum thickness of solid bottom shell, in millimeters (adds layers beyond `bottomShellLayers` if needed).
    ///
    /// Shown as "Bottom shell thickness" in Bambu Studio and its forks, and "Minimum bottom shell thickness" in PrusaSlicer.
    static func bottomShellThickness(_ millimeters: Double) -> Self {
        .init(bambu: .bottomShellThickness, prusa: .bottomSolidMinThickness, number(millimeters))
    }

    /// Sparse infill density, as a whole-number percentage (e.g. `15` for 15%).
    ///
    /// Shown as "Sparse infill density" in Bambu Studio and its forks, and "Fill density" in PrusaSlicer.
    static func infillDensity(_ percent: Int) -> Self {
        .init(bambu: .sparseInfillDensity, prusa: .fillDensity, Self.percent(percent))
    }

    /// Sparse infill pattern.
    ///
    /// A handful of patterns exist in only one slicer family — see ``InfillPattern`` — and are
    /// written only for the family that has them.
    ///
    /// Shown as "Sparse infill pattern" in Bambu Studio and its forks, and "Fill pattern" in PrusaSlicer.
    static func infillPattern(_ pattern: InfillPattern) -> Self {
        .init(bambu: .sparseInfillPattern, pattern.bambuValue, prusa: .fillPattern, pattern.prusaValue)
    }

    /// Length of the infill anchor along the perimeter, in millimeters.
    ///
    /// Bambu Studio renamed this option in its forks, so both spellings are written for that flavor —
    /// each fork reads the one it knows and ignores the other.
    ///
    /// All three slicers also accept a percentage here, which Sprue doesn't expose.
    ///
    /// Shown as "Length of sparse infill anchor" in Bambu Studio, "Sparse infill anchor length" in its forks, and "Length of the infill anchor" in PrusaSlicer.
    static func infillAnchor(_ millimeters: Double) -> Self {
        .init(
            bambu: [.sparseInfillAnchor: String(millimeters), .infillAnchor: String(millimeters)],
            prusa: [.infillAnchor: String(millimeters)]
        )
    }

    /// Maximum length of the infill anchor along the perimeter, in millimeters. See
    /// ``infillAnchor(_:)`` for the double-spelling and percentage notes.
    ///
    /// Shown as "Maximum length of sparse infill anchor" in Bambu Studio, and "Maximum length of the infill anchor" elsewhere.
    static func infillAnchorMax(_ millimeters: Double) -> Self {
        .init(
            bambu: [.sparseInfillAnchorMax: String(millimeters), .infillAnchorMax: String(millimeters)],
            prusa: [.infillAnchorMax: String(millimeters)]
        )
    }

    /// Top surface fill pattern. Only a subset of ``InfillPattern`` applies here — see its documentation.
    ///
    /// Shown as "Top surface pattern" in Bambu Studio and its forks, and "Top fill pattern" in PrusaSlicer.
    static func topSurfacePattern(_ pattern: InfillPattern) -> Self {
        .init(bambu: .topSurfacePattern, pattern.bambuValue, prusa: .topFillPattern, pattern.prusaValue)
    }

    /// Bottom surface fill pattern. Only a subset of ``InfillPattern`` applies here — see its documentation.
    ///
    /// Shown as "Bottom surface pattern" in Bambu Studio and its forks, and "Bottom fill pattern" in PrusaSlicer.
    static func bottomSurfacePattern(_ pattern: InfillPattern) -> Self {
        .init(bambu: .bottomSurfacePattern, pattern.bambuValue, prusa: .bottomFillPattern, pattern.prusaValue)
    }

    /// Internal solid infill pattern. Only a subset of ``InfillPattern`` applies here — see its
    /// documentation. **Bambu Studio and its forks only.**
    ///
    /// PrusaSlicer has no separate pattern for internal solid infill; it uses the sparse infill
    /// pattern from ``infillPattern(_:)`` for solid regions too.
    static func internalSolidInfillPattern(_ pattern: InfillPattern) -> Self {
        .init(bambuOnly: .internalSolidInfillPattern, pattern.bambuValue)
    }

    /// Whether sparse infill is combined across multiple layers to reduce print time.
    /// **Bambu Studio and its forks only.**
    ///
    /// PrusaSlicer's equivalent takes a layer count rather than a flag, so it has no direct
    /// counterpart here.
    static func infillCombination(_ value: Bool) -> Self {
        .init(bambuOnly: .infillCombination, flag(value))
    }

    /// Overlap between infill and walls, as a whole-number percentage of the extrusion width.
    ///
    /// Shown as "Infill/wall overlap" in Bambu Studio and its forks, and "Infill/perimeters overlap" in PrusaSlicer.
    static func infillWallOverlap(_ percent: Int) -> Self {
        .init(bambu: .infillWallOverlap, prusa: .infillOverlap, Self.percent(percent))
    }

    /// Infill line direction.
    ///
    /// Shown as "Infill direction" in Bambu Studio, "Sparse infill direction" in its forks, and "Fill angle" in PrusaSlicer.
    static func infillDirection(_ angle: Angle) -> Self {
        .init(bambu: .infillDirection, prusa: .fillAngle, degrees(angle))
    }

    /// Angle used for bridge infill.
    ///
    /// Shown as "Bridge direction" in Bambu Studio, "External bridge infill direction" in OrcaSlicer, "Bridge infill direction" in Creality Print, and "Bridging angle" in PrusaSlicer.
    static func bridgeAngle(_ angle: Angle) -> Self {
        .init(bambu: .bridgeAngle, prusa: .bridgeAngle, degrees(angle))
    }

    /// Flow ratio used for bridges, relative to the normal flow. **Bambu Studio and its forks only.**
    ///
    /// Shown as "Bridge flow" in Bambu Studio, "Bridge flow ratio" in OrcaSlicer and Creality Print.
    static func bridgeFlow(_ ratio: Double) -> Self {
        .init(bambuOnly: .bridgeFlow, number(ratio))
    }

    /// Below this area, in square millimeters, sparse infill regions are filled solid instead.
    ///
    /// Shown as "Minimum sparse infill threshold" in Bambu Studio and its forks, and "Solid infill threshold area" in PrusaSlicer.
    static func minimumSparseInfillArea(_ squareMillimeters: Double) -> Self {
        .init(bambu: .minimumSparseInfillArea, prusa: .solidInfillBelowArea, number(squareMillimeters))
    }

    // MARK: Multi-material

    /// The (1-based) extruder this object is assigned to print with.
    static func extruder(_ number: Int) -> Self {
        .init(bambu: .extruder, prusa: .extruder, Self.number(number))
    }

    /// Whether filament purged before printing this object can be flushed into its own infill.
    ///
    /// Shown as "Flush into objects' infill" in Bambu Studio and its forks, and "Wipe into this object's infill" in PrusaSlicer.
    static func flushIntoInfill(_ value: Bool) -> Self {
        .init(bambu: .flushIntoInfill, prusa: .wipeIntoInfill, flag(value))
    }

    /// Whether filament purged before printing this object can be flushed into other objects.
    ///
    /// Shown as "Flush into this object" in Bambu Studio and its forks, and "Wipe into this object" in PrusaSlicer.
    static func flushIntoObjects(_ value: Bool) -> Self {
        .init(bambu: .flushIntoObjects, prusa: .wipeIntoObjects, flag(value))
    }

    /// Whether filament purged before printing this object can be flushed into support.
    /// **Bambu Studio and its forks only.**
    ///
    /// Shown as "Flush into objects' support" in Bambu Studio and its forks.
    static func flushIntoSupport(_ value: Bool) -> Self {
        .init(bambuOnly: .flushIntoSupport, flag(value))
    }

}

// MARK: - OrcaSlicer extensions

/// Settings recognized by OrcaSlicer but not vanilla Bambu Studio, and by neither PrusaSlicer nor
/// SuperSlicer. Several of these (noted below) are also recognized by Creality Print, which inherited
/// them from Orca; genuinely Creality-only settings are in a separate extension.
public extension SlicerSetting {
    /// Overhang angle, measured from vertical, beyond which walls are made printable without support.
    /// **OrcaSlicer and Creality Print.**
    ///
    /// Shown as "Make overhangs printable - Maximum angle" in OrcaSlicer and Creality Print.
    static func makeOverhangPrintableAngle(_ angle: Angle) -> Self {
        .init(bambuOnly: .makeOverhangPrintableAngle, degrees(angle))
    }

    /// Maximum size of a hole that "make overhang printable" will fill in, in millimeters.
    /// **OrcaSlicer and Creality Print.**
    ///
    /// Shown as "Make overhangs printable - Hole area" in OrcaSlicer and Creality Print.
    static func makeOverhangPrintableHoleSize(_ millimeters: Double) -> Self {
        .init(bambuOnly: .makeOverhangPrintableHoleSize, number(millimeters))
    }

    /// Whether steep overhangs are reworked so they can be printed without support. **OrcaSlicer and Creality Print.**
    ///
    /// Shown as "Make overhangs printable" in OrcaSlicer and Creality Print.
    static func makeOverhangPrintable(_ value: Bool) -> Self {
        .init(bambuOnly: .makeOverhangPrintable, flag(value))
    }

    /// Flow ratio used for the brim, relative to the normal flow. **OrcaSlicer only.**
    ///
    /// Shown as "Brim flow ratio" in OrcaSlicer.
    static func brimFlowRatio(_ ratio: Double) -> Self {
        .init(bambuOnly: .brimFlowRatio, number(ratio))
    }

    /// Whether the brim follows the elephant-foot-compensated outline instead of the nominal one.
    /// **OrcaSlicer only.**
    ///
    /// Shown as "Brim follows compensated outline" in OrcaSlicer.
    static func brimFollowsCompensatedOutline(_ value: Bool) -> Self {
        .init(bambuOnly: .brimUseEfcOutline, flag(value))
    }

    /// Overlap fraction, as a whole-number percentage, needed before an overhang triggers support.
    /// **OrcaSlicer only.**
    ///
    /// Shown as "Threshold overlap" in OrcaSlicer.
    static func supportThresholdOverlap(_ percent: Int) -> Self {
        .init(bambuOnly: .supportThresholdOverlap, Self.percent(percent))
    }

    /// Brim width around tree supports, in millimeters. **OrcaSlicer and Creality Print.**
    ///
    /// Shown as "Tree support brim width" in OrcaSlicer and Creality Print.
    static func treeSupportBrimWidth(_ millimeters: Double) -> Self {
        .init(bambuOnly: .treeSupportBrimWidth, number(millimeters))
    }

    /// Branch angle for organic-style tree supports. **OrcaSlicer and Creality Print.**
    ///
    /// Shown as "Tree support branch angle" in OrcaSlicer and Creality Print.
    static func treeSupportBranchAngleOrganic(_ angle: Angle) -> Self {
        .init(bambuOnly: .treeSupportBranchAngleOrganic, degrees(angle))
    }

    /// Density of bridge infill, as a whole-number percentage. **OrcaSlicer and Creality Print.**
    ///
    /// Shown as "External bridge density" in OrcaSlicer, "Bridge density" in Creality Print.
    static func bridgeDensity(_ percent: Int) -> Self {
        .init(bambuOnly: .bridgeDensity, Self.percent(percent))
    }

    /// Extra flow applied while ironing, in addition to `ironingFlow`. **OrcaSlicer only.**
    ///
    /// Shown as "Ironing expansion" in OrcaSlicer.
    static func ironingExpansion(_ millimeters: Double) -> Self {
        .init(bambuOnly: .ironingExpansion, number(millimeters))
    }

    /// Whether Z-layer contouring ("Z anti-aliasing") is enabled — reduces the height of top-surface
    /// perimeters to more closely match the model's true edge height. **OrcaSlicer only.**
    ///
    /// Shown as "Z contouring enabled" in OrcaSlicer.
    static func zContouringEnabled(_ value: Bool) -> Self {
        .init(bambuOnly: .zContouringEnabled, flag(value))
    }

    /// Under Z-layer contouring, perimeters sloped less steeply than this angle have their height
    /// reduced to match the model's edge. `0°` disables this. **OrcaSlicer only.**
    ///
    /// Shown as "Minimize wall height angle" in OrcaSlicer.
    static func zContouringMinimizeWallHeightAngle(_ angle: Angle) -> Self {
        .init(bambuOnly: .zContouringMinimizeWallHeightAngle, degrees(angle))
    }

    /// Whether Z-layer contouring skips alternating its fill direction between layers.
    /// **OrcaSlicer only.**
    ///
    /// Shown as "Don't alternate fill direction" in OrcaSlicer.
    static func zContouringDisableAlternatingFillDirection(_ value: Bool) -> Self {
        .init(bambuOnly: .zContouringDisableAlternatingFillDirection, flag(value))
    }

    /// Minimum Z-layer height used by Z-layer contouring, in millimeters. Also controls the slicing
    /// plane. **OrcaSlicer only.**
    ///
    /// Shown as "Minimum Z height" in OrcaSlicer.
    static func zContouringMinimumZHeight(_ millimeters: Double) -> Self {
        .init(bambuOnly: .zContouringMinimumZHeight, number(millimeters))
    }

    /// Density of the top surface's solid infill, as a whole-number percentage. **OrcaSlicer only.**
    ///
    /// Shown as "Top surface density" in OrcaSlicer.
    static func topSurfaceDensity(_ percent: Int) -> Self {
        .init(bambuOnly: .topSurfaceDensity, Self.percent(percent))
    }

    /// Density of the bottom surface's solid infill, as a whole-number percentage. **OrcaSlicer only.**
    ///
    /// Shown as "Bottom surface density" in OrcaSlicer.
    static func bottomSurfaceDensity(_ percent: Int) -> Self {
        .init(bambuOnly: .bottomSurfaceDensity, Self.percent(percent))
    }

    /// Number of lines used per pass for infill patterns that support multi-line infill (1–10).
    /// **OrcaSlicer and Creality Print.**
    ///
    /// Shown as "Fill Multiline" in OrcaSlicer and Creality Print.
    static func fillMultiline(_ count: Int) -> Self {
        .init(bambuOnly: .fillMultiline, number(count))
    }

    /// Angle of the first set of lattice infill elements in the Z direction (zero is vertical).
    /// **OrcaSlicer and Creality Print.**
    ///
    /// Shown as "Lateral lattice angle 1" in OrcaSlicer and Creality Print.
    static func lateralLatticeAngle1(_ angle: Angle) -> Self {
        .init(bambuOnly: .lateralLatticeAngle1, degrees(angle))
    }

    /// Angle of the second set of lattice infill elements in the Z direction (zero is vertical).
    /// **OrcaSlicer and Creality Print.**
    ///
    /// Shown as "Lateral lattice angle 2" in OrcaSlicer and Creality Print.
    static func lateralLatticeAngle2(_ angle: Angle) -> Self {
        .init(bambuOnly: .lateralLatticeAngle2, degrees(angle))
    }

    /// Angle of infill's angled lines (60° produces a pure honeycomb). **OrcaSlicer and Creality Print.**
    ///
    /// Shown as "Infill overhang angle" in OrcaSlicer and Creality Print.
    static func infillOverhangAngle(_ angle: Angle) -> Self {
        .init(bambuOnly: .infillOverhangAngle, degrees(angle))
    }

    /// Overhang angle used by lightning infill. **OrcaSlicer only.**
    ///
    /// Shown as "Lightning overhang angle" in OrcaSlicer.
    static func lightningOverhangAngle(_ angle: Angle) -> Self {
        .init(bambuOnly: .lightningOverhangAngle, degrees(angle))
    }

    /// Branch-pruning angle used by lightning infill. **OrcaSlicer only.**
    ///
    /// Shown as "Prune angle" in OrcaSlicer.
    static func lightningPruneAngle(_ angle: Angle) -> Self {
        .init(bambuOnly: .lightningPruneAngle, degrees(angle))
    }

    /// Branch-straightening angle used by lightning infill. **OrcaSlicer only.**
    ///
    /// Shown as "Straightening angle" in OrcaSlicer.
    static func lightningStraighteningAngle(_ angle: Angle) -> Self {
        .init(bambuOnly: .lightningStraighteningAngle, degrees(angle))
    }

    /// Distance the top surface is expanded outward to merge small gaps, in millimeters.
    /// **OrcaSlicer only.**
    ///
    /// Shown as "Top surface expansion" in OrcaSlicer.
    static func topSurfaceExpansion(_ millimeters: Double) -> Self {
        .init(bambuOnly: .topSurfaceExpansion, number(millimeters))
    }

    /// Margin used while computing top surface expansion, in millimeters. **OrcaSlicer only.**
    ///
    /// Shown as "Top expansion wall margin" in OrcaSlicer.
    static func topSurfaceExpansionMargin(_ millimeters: Double) -> Self {
        .init(bambuOnly: .topSurfaceExpansionMargin, number(millimeters))
    }

    /// Direction top surface expansion grows in. **OrcaSlicer only.**
    ///
    /// Shown as "Top expansion direction" in OrcaSlicer.
    static func topSurfaceExpansionDirection(_ direction: TopSurfaceExpansionDirection) -> Self {
        .init(bambuOnly: .topSurfaceExpansionDirection, direction.rawValue)
    }

    /// Whether solid infill direction rotates to align with the model rather than staying fixed.
    /// **OrcaSlicer and Creality Print.**
    ///
    /// Shown as "Align directions to model" in OrcaSlicer, "Align infill direction to model" in Creality Print.
    static func alignInfillDirectionToModel(_ value: Bool) -> Self {
        .init(bambuOnly: .alignInfillDirectionToModel, flag(value))
    }

    /// Inserts solid infill at specific layers. Accepts `"N"` (every Nth layer), `"N#K"` (K consecutive
    /// solid layers every N layers), or a comma-separated explicit layer list (e.g. `"1,7,9"`; layers
    /// are 1-based). **OrcaSlicer only.**
    ///
    /// Shown as "Insert solid layers" in OrcaSlicer.
    static func extraSolidInfills(_ spec: String) -> Self {
        .init(bambuOnly: .extraSolidInfills, spec)
    }

    /// Maximum combined layer height when combining sparse infill across multiple layers, in
    /// millimeters. **OrcaSlicer and Creality Print.**
    ///
    /// OrcaSlicer also accepts a percentage here, which Sprue doesn't expose.
    ///
    /// Shown as "Infill combination - Max layer height" in OrcaSlicer and Creality Print.
    static func infillCombinationMaxLayerHeight(_ millimeters: Double) -> Self {
        .init(bambuOnly: .infillCombinationMaxLayerHeight, number(millimeters))
    }

    /// Overlap between infill and the top/bottom solid shell, as a whole-number percentage.
    /// **OrcaSlicer and Creality Print.**
    ///
    /// Shown as "Top/Bottom solid infill/wall overlap" in OrcaSlicer and Creality Print.
    static func topBottomInfillWallOverlap(_ percent: Int) -> Self {
        .init(bambuOnly: .topBottomInfillWallOverlap, Self.percent(percent))
    }

    /// Solid infill line direction. **OrcaSlicer and Creality Print.**
    ///
    /// Shown as "Solid infill direction" in OrcaSlicer and Creality Print.
    static func solidInfillDirection(_ angle: Angle) -> Self {
        .init(bambuOnly: .solidInfillDirection, degrees(angle))
    }

    /// Top solid layer line direction. **OrcaSlicer only.**
    ///
    /// Shown as "Top layer direction" in OrcaSlicer.
    static func topLayerDirection(_ angle: Angle) -> Self {
        .init(bambuOnly: .topLayerDirection, degrees(angle))
    }

    /// Bottom solid layer line direction. **OrcaSlicer only.**
    ///
    /// Shown as "Bottom layer direction" in OrcaSlicer.
    static func bottomLayerDirection(_ angle: Angle) -> Self {
        .init(bambuOnly: .bottomLayerDirection, degrees(angle))
    }

    /// Angle used for internal bridge infill. **OrcaSlicer only.**
    ///
    /// Shown as "Internal bridge infill direction" in OrcaSlicer.
    static func internalBridgeAngle(_ angle: Angle) -> Self {
        .init(bambuOnly: .internalBridgeAngle, degrees(angle))
    }
}

// MARK: - Creality Print extensions

/// Settings recognized by Creality Print but not vanilla Bambu Studio, OrcaSlicer, or PrusaSlicer.
public extension SlicerSetting {
    /// Number of walls supporting tree support branches, for the "tree" support style specifically.
    /// **Creality Print only.**
    ///
    /// Shown as "Support wall loops(Tree)" in Creality Print.
    static func treeSupportWallCountTree(_ count: Int) -> Self {
        .init(bambuOnly: .treeSupportWallCountTree, number(count))
    }

    /// Support base pattern, for the "tree" support style specifically. **Creality Print only.**
    ///
    /// Shown as "Base pattern(Tree)" in Creality Print.
    static func supportBasePatternTree(_ pattern: SupportBasePattern) -> Self {
        .init(bambuOnly: .supportBasePatternTree, pattern.bambuValue)
    }

    /// Minimum area a support interface region must have to be generated, in square millimeters.
    /// **Creality Print only.**
    ///
    /// Shown as "Minimum Support Contact Area" in Creality Print.
    static func supportInterfaceMinArea(_ squareMillimeters: Double) -> Self {
        .init(bambuOnly: .supportInterfaceMinArea, number(squareMillimeters))
    }

    /// Whether organic tree supports are validated and automatically repaired if invalid.
    /// **Creality Print only.**
    ///
    /// Shown as "Validation and Repair Support" in Creality Print.
    static func treeSupportOrganicValidateRepair(_ value: Bool) -> Self {
        .init(bambuOnly: .treeSupportOrganicValidateRepair, flag(value))
    }

    /// Whether solid infill direction rotates a fixed amount between layers. **Creality Print only.**
    ///
    /// Shown as "Rotate solid infill direction" in Creality Print.
    static func rotateSolidInfillDirection(_ value: Bool) -> Self {
        .init(bambuOnly: .rotateSolidInfillDirection, flag(value))
    }

    /// Whether the classic (pre-Arachne) overhang speed algorithm is used. **Creality Print only.**
    ///
    /// Shown as "Classic mode" in Creality Print.
    static func overhangSpeedClassic(_ value: Bool) -> Self {
        .init(bambuOnly: .overhangSpeedClassic, flag(value))
    }
}

/// One component's settings, collapsed to one value per key within each flavor.
struct ResolvedSlicerSettings: Sendable, Hashable {
    var bambu: [BambuSettingKey: String] = [:]
    var prusa: [PrusaSettingKey: String] = [:]

    var isEmpty: Bool { bambu.isEmpty && prusa.isEmpty }
}

internal extension Array where Element == SlicerSetting {
    /// Collapses to one value per key (last one wins on duplicates), matching how the underlying
    /// config storage is keyed. Each flavor is collapsed independently, so a later single-key setting
    /// overrides the same key coming from an earlier grouped one, e.g. `[.infill(.gyroid, density: 20),
    /// .infillDensity(50)]` ends up at 50% in both files.
    var resolved: ResolvedSlicerSettings {
        reduce(into: ResolvedSlicerSettings()) { result, setting in
            result.bambu.merge(setting.bambu) { _, new in new }
            result.prusa.merge(setting.prusa) { _, new in new }
        }
    }
}
