import Foundation
import Testing
import Cadova
import Zip
@testable import Sprue

/// End-to-end coverage: what actually lands in the finished 3MF, read back out of the archive rather
/// than taken from Sprue's own bookkeeping.
struct SlicerConfigArchiveTests {
    @Test func `prusa volume range matches the mesh actually written`() async throws {
        // The one that matters most. PrusaSlicer validates this range against the serialized mesh and
        // fails the whole load when lastid runs past the end; a range that's merely short silently
        // drops triangles. Nothing else in the pipeline would catch an off-by-one or a mis-scoped
        // measurement, so this compares against the triangles genuinely present in the archive.
        let platter = Box(x: 20, y: 20, z: 10)
            .inComponent(name: "Blocky", slicerSettings: [.infillDensity(15)])
            .adding {
                Sphere(radius: 8)
                    .inComponent(name: "Round", slicerSettings: [.wallCount(4)])
            }
            .onPlatter()

        let data = try await ModelFileGenerator.build { platter }.data()
        let archive = try ZipArchive(data: data)

        let counts = try archive.serializedTriangleCounts()
        let ranges = try archive.prusaVolumeRanges()

        #expect(ranges.count == 2)
        for (id, range) in ranges {
            let triangleCount = try #require(counts[id], "no serialized mesh for object \(id)")
            #expect(triangleCount > 0)
            #expect(range.firstID == 0)
            #expect(range.lastID == triangleCount - 1)
        }
    }

    @Test func `multiplied components get their own volume ranges`() async throws {
        // A quantity above 1 makes packing emit each copy as its own renamed part, so the settings
        // and the volume range have to follow the *packed* part rather than the one the component
        // declared. Distinct shapes here so a mix-up between copies couldn't pass by coincidence.
        let platter = Cylinder(diameter: 12, height: 6).withSegmentation(count: 6)
            .inComponent(name: "Hex", quantity: 3, slicerSettings: [.infillDensity(35)])
            .adding {
                Sphere(radius: 7)
                    .inComponent(name: "Ball", slicerSettings: [.wallCount(2)])
            }
            .onPlatter()

        let data = try await ModelFileGenerator.build { platter }.data()
        let archive = try ZipArchive(data: data)

        let counts = try archive.serializedTriangleCounts()
        let ranges = try archive.prusaVolumeRanges()

        #expect(ranges.count == 4) // three hex copies plus the ball
        for (id, range) in ranges {
            let triangleCount = try #require(counts[id], "no serialized mesh for object \(id)")
            #expect(range.lastID == triangleCount - 1)
        }
        // The sphere is far denser than the hex prism, so the ranges must not all be identical.
        #expect(Set(ranges.values.map(\.lastID)).count > 1)
    }

    @Test func `nested parts are excluded from the volume range`() async throws {
        // Regression for the measurement scope. A part's geometry can still carry nested parts, which
        // the 3MF writer emits as their own objects rather than as part of this mesh — measuring with
        // the default `.solidParts` scope would count them twice over and overshoot the range, which
        // PrusaSlicer rejects outright.
        //
        // Deliberately *without* onPlatter(): packing strips nested parts out of a component, so
        // routing this through the platter would leave nothing nested to get the scope wrong about.
        // The sphere is far denser than the box, so a mis-scoped count overshoots by three orders of
        // magnitude.
        let component = Box(x: 20, y: 20, z: 10)
            .adding {
                Sphere(radius: 6)
                    .translated(x: 40)
                    .inPart(Part("Tagalong"))
            }
            .inComponent(name: "Host", slicerSettings: [.infillDensity(15)])

        let data = try await ModelFileGenerator.build { component }.data()
        let archive = try ZipArchive(data: data)

        let counts = try archive.serializedTriangleCounts()
        let ranges = try archive.prusaVolumeRanges()

        #expect(!ranges.isEmpty)
        for (id, range) in ranges {
            let triangleCount = try #require(counts[id])
            #expect(range.lastID == triangleCount - 1)
        }
    }

    @Test func `onPlatter embeds both config sidecars for components with slicer settings`() async throws {
        // End-to-end: a component declared with slicerSettings must cause onPlatter() to embed both
        // sidecars, so the one file configures Bambu-lineage slicers and PrusaSlicer alike.
        let component = Component("Configured", upDirection: .up, slicerSettings: [.infillDensity(15)])
        let platter = Box(10)
            .inComponent(component)
            .onPlatter()

        let data = try await ModelFileGenerator.build { platter }.data()
        let archive = try ZipArchive(data: data)

        #expect(archive.hasEntry(at: SlicerSettingsEntries.bambuConfigPath))
        #expect(archive.hasEntry(at: SlicerSettingsEntries.prusaConfigPath))

        #expect(try archive.text(at: SlicerSettingsEntries.bambuConfigPath)
            .contains(#"key="sparse_infill_density" value="15%""#))
        #expect(try archive.text(at: SlicerSettingsEntries.prusaConfigPath)
            .contains(#"key="fill_density" value="15%""#))
    }

    @Test func `configured components keep their names in Bambu Studio`() async throws {
        // Regression: Bambu Studio's reader has two mutually exclusive branches. Without a config
        // block it names an object from the 3MF <object name> attribute; *with* one it uses only the
        // block's `name` metadata and never looks at the attribute. So every component that had
        // slicer settings loaded with a blank name, while the ones without settings were fine.
        let platter = Stack(.x, spacing: 1) {
            Box(10)
                .inComponent(name: "Foo", upDirection: .up, slicerSettings: [.infill(.gyroid, density: 20)])
            Box(15)
                .inComponent(name: "Larger", upDirection: .up, slicerSettings: [])
            Box(20)
                .inComponent(name: "Huge", upDirection: .up, slicerSettings: [.support(.treeAuto)])
        }
        .onPlatter()

        let data = try await ModelFileGenerator.build { platter }.data()
        let archive = try ZipArchive(data: data)

        let modelNames = try archive.modelObjectNames()
        let bambuNames = try archive.bambuObjectNames()

        // The two configured components are the ones at risk; the unconfigured one gets no block.
        #expect(Set(modelNames.values) == ["Foo", "Larger", "Huge"])
        #expect(bambuNames.count == 2)
        for (id, name) in bambuNames {
            #expect(name == modelNames[id], "object \(id) is named \(name ?? "nil") in the config")
        }
        #expect(Set(bambuNames.values.compactMap { $0 }) == ["Foo", "Huge"])
    }

    @Test func `a setting only one slicer supports writes only that slicer's file`() async throws {
        // A component configured purely with fork-only settings has nothing to say to PrusaSlicer, so
        // that sidecar must be left out rather than written empty (or, worse, written with keys
        // PrusaSlicer would choke on).
        let component = Component("Orca Only", upDirection: .up, slicerSettings: [.zContouringEnabled(true)])
        let platter = Box(10)
            .inComponent(component)
            .onPlatter()

        let data = try await ModelFileGenerator.build { platter }.data()
        let archive = try ZipArchive(data: data)

        #expect(archive.hasEntry(at: SlicerSettingsEntries.bambuConfigPath))
        #expect(!archive.hasEntry(at: SlicerSettingsEntries.prusaConfigPath))
    }

    @Test func `onPlatter omits configs without slicer settings`() async throws {
        // No component declared slicerSettings, so no sidecar file should be added at all.
        let component = Component("Plain", upDirection: .up)
        let platter = Box(10)
            .inComponent(component)
            .onPlatter()

        let data = try await ModelFileGenerator.build { platter }.data()
        let archive = try ZipArchive(data: data)

        #expect(!archive.hasEntry(at: SlicerSettingsEntries.bambuConfigPath))
        #expect(!archive.hasEntry(at: SlicerSettingsEntries.prusaConfigPath))
    }

    @Test func `inComponent embeds configs without onPlatter`() async throws {
        // slicerSettings must not require onPlatter() — a bare inComponent, exported directly, should
        // still embed the sidecars (inComponent's own part is never renamed/copied without packing,
        // so it resolves to a real object id on its own).
        let component = Box(10).inComponent(Component("Standalone", upDirection: .up, slicerSettings: [.wallCount(3)]))

        let data = try await ModelFileGenerator.build { component }.data()
        let archive = try ZipArchive(data: data)

        #expect(archive.hasEntry(at: SlicerSettingsEntries.bambuConfigPath))
        #expect(archive.hasEntry(at: SlicerSettingsEntries.prusaConfigPath))
    }

    @Test func `multiple components share one config of each kind without crashing`() async throws {
        // Every component with slicerSettings registers its own archive finalizer independently. With
        // two components in the same export, both run — this must not throw (a naive "just always
        // addFile" implementation would throw ZipError.duplicateFileEntry on the second one).
        let a = Component("A", upDirection: .up, slicerSettings: [.infillDensity(15)])
        let b = Component("B", upDirection: .up, slicerSettings: [.infillDensity(80)])
        let assembly = Box(10)
            .inComponent(a)
            .adding {
                Box(5)
                    .inComponent(b)
            }

        let data = try await ModelFileGenerator.build { assembly }.data()
        let archive = try ZipArchive(data: data)

        // Both components land in one file per flavor, each as its own <object> block.
        let bambu = try archive.text(at: SlicerSettingsEntries.bambuConfigPath)
        #expect(bambu.fragments(forTag: "object").count == 2)

        let prusa = try archive.text(at: SlicerSettingsEntries.prusaConfigPath)
        #expect(prusa.fragments(forTag: "object").count == 2)
        #expect(prusa.fragments(forTag: "volume").count == 2)
    }
}
