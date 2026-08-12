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
