import Foundation
import Testing
import Cadova
@testable import Sprue

struct SlicerSettingGroupTests {
    @Test func `grouped settings omit unspecified parameters`() {
        // The defining property of the grouped factories: a parameter left out writes *nothing*, so
        // the user's own slicer profile default survives. Writing a default of our own choosing here
        // would silently override settings they never asked us to touch.
        #expect(SlicerSetting.infill(.gyroid).bambu == [.sparseInfillPattern: "gyroid"])
        #expect(SlicerSetting.infill(.gyroid).prusa == [.fillPattern: "gyroid"])

        #expect(SlicerSetting.infill(.gyroid, density: 20).prusa == [
            .fillPattern: "gyroid",
            .fillDensity: "20%",
        ])

        #expect(SlicerSetting.infill(.lightning, density: 10, direction: 45°).bambu == [
            .sparseInfillPattern: "lightning",
            .sparseInfillDensity: "10%",
            .infillDirection: "45.0",
        ])

        // A group where every parameter is optional collapses to nothing at all rather than to defaults.
        #expect(SlicerSetting.flush().bambu.isEmpty)
        #expect(SlicerSetting.flush().prusa.isEmpty)
    }

    @Test func `lateral lattice infill carries the pattern its angles need`() {
        // The angles are inert without the pattern, so the group has to select it. Before the pattern
        // existed, lateralLatticeAngle1/2 could be set but never took effect.
        #expect(SlicerSetting.lateralLatticeInfill(angle1: 30°, angle2: 60°).bambu == [
            .sparseInfillPattern: "lateral-lattice",
            .lateralLatticeAngle1: "30.0",
            .lateralLatticeAngle2: "60.0",
        ])

        // Naming the pattern alone is a complete, if unshaped, use of the group.
        #expect(SlicerSetting.lateralLatticeInfill().bambu == [.sparseInfillPattern: "lateral-lattice"])

        // Pattern and angles are all OrcaSlicer-family, so PrusaSlicer gets nothing at all rather
        // than a bare density that would apply to whatever pattern its profile already has.
        #expect(SlicerSetting.lateralLatticeInfill(angle1: 30°).prusa.isEmpty)

        // Density is universal, so it still reaches PrusaSlicer; the pattern does not.
        #expect(SlicerSetting.lateralLatticeInfill(density: 15).prusa == [.fillDensity: "15%"])
    }

    @Test func `the lateral lattice pattern uses OrcaSlicer's own spelling`() {
        // "lateral-lattice" comes from s_keys_map_InfillPattern in OrcaSlicer's PrintConfig.cpp, which
        // is what its config serialization reads. The internal C++ name was once ip2DLattice, so
        // "2dlattice" is a plausible-looking wrong answer.
        #expect(SlicerSetting.infillPattern(.lateralLattice).bambu == [.sparseInfillPattern: "lateral-lattice"])
        #expect(SlicerSetting.infillPattern(.lateralLattice).prusa.isEmpty)
    }

    @Test func `grouped support implies the enable flag`() {
        // Regression: a support type without the enable flag does nothing in either slicer, so a part
        // would silently print unsupported. Naming a type has to imply the enable flag.
        #expect(SlicerSetting.support(.treeAuto).bambu == [
            .enableSupport: "1",
            .supportType: "tree(auto)",
        ])
        #expect(SlicerSetting.support(.treeAuto).prusa == [
            .supportMaterial: "1",
            .supportMaterialStyle: "organic",
            .supportMaterialAuto: "1",
        ])

        #expect(SlicerSetting.support(.normalAuto, style: .snug, thresholdAngle: 40°, onBuildPlateOnly: true).bambu == [
            .enableSupport: "1",
            .supportType: "normal(auto)",
            .supportStyle: "snug",
            .supportThresholdAngle: "40",
            .supportOnBuildPlateOnly: "1",
        ])

        // An explicit style has to win over the one implied by the type, in both flavors.
        #expect(SlicerSetting.support(.normalAuto, style: .snug).prusa[.supportMaterialStyle] == "snug")

        #expect(SlicerSetting.noSupport.bambu == [.enableSupport: "0"])
        #expect(SlicerSetting.noSupport.prusa == [.supportMaterial: "0"])
    }
}
