import Foundation
import Testing
import Cadova
@testable import Sprue

struct SlicerSettingTests {
    @Test func `infill pattern lowers to each slicer's own vocabulary`() {
        // Regression: Bambu Studio's raw config value for the pattern labeled "Rectilinear" in its UI
        // is, confusingly, "zig-zag" — and a *separate* raw value "zigzag" (no hyphen) exists for the
        // actual "Zig Zag" pattern. PrusaSlicer spells the first one plainly. Getting these crossed
        // would silently write the wrong pattern.
        #expect(SlicerSetting.infillPattern(.rectilinear).bambu == [.sparseInfillPattern: "zig-zag"])
        #expect(SlicerSetting.infillPattern(.rectilinear).prusa == [.fillPattern: "rectilinear"])
        #expect(SlicerSetting.infillPattern(.zigzag).bambu == [.sparseInfillPattern: "zigzag"])

        // PrusaSlicer pluralizes this one.
        #expect(SlicerSetting.infillPattern(.monotonicLine).bambu == [.sparseInfillPattern: "monotonicline"])
        #expect(SlicerSetting.infillPattern(.monotonicLine).prusa == [.fillPattern: "monotoniclines"])
    }

    @Test func `patterns missing from a slicer are omitted rather than approximated`() {
        // A pattern only one slicer has must contribute *nothing* to the other's config. Substituting
        // a near-enough pattern would silently print something the caller didn't ask for; writing the
        // unknown name verbatim would make PrusaSlicer refuse to open the file.
        #expect(SlicerSetting.infillPattern(.crossHatch).bambu == [.sparseInfillPattern: "crosshatch"])
        #expect(SlicerSetting.infillPattern(.crossHatch).prusa.isEmpty)

        #expect(SlicerSetting.infillPattern(.stars).prusa == [.fillPattern: "stars"])
        #expect(SlicerSetting.infillPattern(.stars).bambu.isEmpty)

        // Same rule for the other divergent vocabularies.
        #expect(SlicerSetting.brimType(.painted).prusa.isEmpty)
        #expect(SlicerSetting.supportBasePattern(.lightning).prusa.isEmpty)
        #expect(SlicerSetting.wallSequence(.innerOuterInner).prusa.isEmpty)
    }

    @Test func `typed factories produce the expected raw values`() {
        #expect(SlicerSetting.enableSupport(true).bambu == [.enableSupport: "1"])
        #expect(SlicerSetting.enableSupport(true).prusa == [.supportMaterial: "1"])
        #expect(SlicerSetting.enableSupport(false).bambu == [.enableSupport: "0"])

        #expect(SlicerSetting.wallCount(3).bambu == [.wallLoops: "3"])
        #expect(SlicerSetting.wallCount(3).prusa == [.perimeters: "3"])

        #expect(SlicerSetting.infillDensity(15).bambu == [.sparseInfillDensity: "15%"])
        #expect(SlicerSetting.infillDensity(15).prusa == [.fillDensity: "15%"])

        #expect(SlicerSetting.layerHeight(0.2).bambu == [.layerHeight: "0.2"])
        #expect(SlicerSetting.layerHeight(0.2).prusa == [.layerHeight: "0.2"])

        // PrusaSlicer calls the rearmost seam position "rear" rather than "back".
        #expect(SlicerSetting.seamPosition(.back).bambu == [.seamPosition: "back"])
        #expect(SlicerSetting.seamPosition(.back).prusa == [.seamPosition: "rear"])

        #expect(SlicerSetting.brimType(.outerOnly).bambu == [.brimType: "outer_only"])
        #expect(SlicerSetting.supportStyle(.treeOrganic).bambu == [.supportStyle: "tree_organic"])
        #expect(SlicerSetting.supportStyle(.treeOrganic).prusa == [.supportMaterialStyle: "organic"])

        // PrusaSlicer's support_material_style accepts only grid, snug and organic. Bambu's three
        // tuned tree variants have to land on organic; writing a "tree" value it doesn't define would
        // be substituted away or rejected, silently giving grid support instead of a tree.
        for style in [SupportStyle.treeSlim, .treeStrong, .treeHybrid] {
            #expect(SlicerSetting.supportStyle(style).prusa == [.supportMaterialStyle: "organic"])
        }
        #expect(SlicerSetting.supportBasePattern(.rectilinearGrid).bambu == [.supportBasePattern: "rectilinear-grid"])

        // The escape hatches are flavor-scoped, so a raw key can't land in the wrong file.
        #expect(SlicerSetting.raw(bambu: .enableSupport, "1").bambu == [.enableSupport: "1"])
        #expect(SlicerSetting.raw(bambu: .enableSupport, "1").prusa.isEmpty)
        #expect(SlicerSetting.raw(prusa: .supportMaterial, "1").prusa == [.supportMaterial: "1"])
        #expect(SlicerSetting.raw(prusa: .supportMaterial, "1").bambu.isEmpty)
    }

    @Test func `settings split across several options in one slicer`() {
        // Bambu folds the support algorithm and its automatic placement into one option; PrusaSlicer
        // keeps them apart, so one neutral setting has to lower to two keys there.
        #expect(SlicerSetting.supportType(.treeAuto).bambu == [.supportType: "tree(auto)"])
        #expect(SlicerSetting.supportType(.treeAuto).prusa == [
            .supportMaterialStyle: "organic",
            .supportMaterialAuto: "1",
        ])
        #expect(SlicerSetting.supportType(.normalManual).prusa == [
            .supportMaterialStyle: "grid",
            .supportMaterialAuto: "0",
        ])

        // PrusaSlicer has no "no ironing" mode — it has a separate flag for that.
        #expect(SlicerSetting.ironingType(.noIroning).bambu == [.ironingType: "no ironing"])
        #expect(SlicerSetting.ironingType(.noIroning).prusa == [.ironing: "0"])
        #expect(SlicerSetting.ironingType(.topmost).prusa == [.ironing: "1", .ironingType: "topmost"])
    }

    @Test func `angles are written as degrees whichever unit they were built from`() {
        // Both config formats want a bare number of degrees, so an angle expressed in any other unit
        // has to be converted rather than serialized as whatever it was constructed with.
        #expect(SlicerSetting.infillDirection(.radians(.pi / 4)).bambu == [.infillDirection: "45.0"])
        #expect(SlicerSetting.infillDirection(.radians(.pi / 4)).prusa == [.fillAngle: "45.0"])
        #expect(SlicerSetting.infillDirection(Angle(turns: 0.25)).prusa == [.fillAngle: "90.0"])

        // The support threshold is an integer option in both slicers, so it must not pick up a
        // fractional part from the Angle round-trip the way the double-valued angles do.
        #expect(SlicerSetting.supportThresholdAngle(40°).bambu == [.supportThresholdAngle: "40"])
        #expect(SlicerSetting.supportThresholdAngle(40°).prusa == [.supportMaterialThreshold: "40"])
        #expect(SlicerSetting.supportThresholdAngle(.radians(.pi / 4)).prusa == [.supportMaterialThreshold: "45"])
    }

    @Test func `later settings override earlier grouped ones per key`() {
        // Groups and single-option factories mix in one array; collapsing is per key within each
        // flavor, last one wins, so a single setting can refine one value out of a group without
        // discarding the rest of it.
        let settings: [SlicerSetting] = [
            .infill(.gyroid, density: 20),
            .infillDensity(50),
        ]

        #expect(settings.resolved.bambu == [
            .sparseInfillPattern: "gyroid",
            .sparseInfillDensity: "50%",
        ])
        #expect(settings.resolved.prusa == [
            .fillPattern: "gyroid",
            .fillDensity: "50%",
        ])
    }

    @Test func `fork-only settings never reach the prusa config`() {
        // OrcaSlicer/Creality extensions have no PrusaSlicer equivalent. Leaking one into that file
        // would make PrusaSlicer throw on the unknown key and refuse to open the whole 3MF.
        #expect(SlicerSetting.zContouringEnabled(true).bambu == [.zContouringEnabled: "1"])
        #expect(SlicerSetting.zContouringEnabled(true).prusa.isEmpty)

        #expect(SlicerSetting.topSurfaceExpansionDirection(.outward).prusa.isEmpty)
        #expect(SlicerSetting.supportBasePatternTree(.honeycomb).bambu == [.supportBasePatternTree: "honeycomb"])
        #expect(SlicerSetting.supportBasePatternTree(.honeycomb).prusa.isEmpty)
        #expect(SlicerSetting.overhangSpeedClassic(false).bambu == [.overhangSpeedClassic: "0"])
        #expect(SlicerSetting.overhangSpeedClassic(false).prusa.isEmpty)

        // Bambu renamed the anchor options in its forks, so both spellings go into that flavor's
        // file — each fork reads the one it knows. PrusaSlicer gets only its own.
        #expect(SlicerSetting.infillAnchor(50).bambu == [.sparseInfillAnchor: "50.0", .infillAnchor: "50.0"])
        #expect(SlicerSetting.infillAnchor(50).prusa == [.infillAnchor: "50.0"])
    }
}
