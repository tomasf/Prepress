import Foundation
import Testing
import Cadova
import Zip
@testable import Prepress

struct PartConfigurationTests {
    @Test func `withSlicerSettings configures a plain part with no component`() async throws {
        // The motivating case: settings on a part that never goes anywhere near a Component.
        let pips = Part("Pips", semantic: .solid)
        let model = Sphere(radius: 2)
            .withSlicerSettings([.infillDensity(15)])
            .inPart(pips)

        let data = try await ModelFileGenerator.build { model }.data()
        let archive = try ZipArchive(data: data)

        #expect(archive.hasEntry(at: SlicerSettingsEntries.bambuConfigPath))
        #expect(archive.hasEntry(at: SlicerSettingsEntries.prusaConfigPath))
        #expect(try archive.text(at: SlicerSettingsEntries.bambuConfigPath)
            .contains(#"key="sparse_infill_density" value="15%""#))
        #expect(try archive.text(at: SlicerSettingsEntries.prusaConfigPath)
            .contains(#"key="fill_density" value="15%""#))
    }

    @Test func `withSlicerSettings takes its settings variadically`() async throws {
        // The bracket-free spelling. Also a check that the variadic overload forwards to the array
        // one rather than resolving back to itself, which would recurse forever.
        let pips = Part("Pips", semantic: .solid)
        let model = Sphere(radius: 2)
            .withSlicerSettings(.infillDensity(15), .wallCount(4))
            .inPart(pips)

        let data = try await ModelFileGenerator.build { model }.data()
        let archive = try ZipArchive(data: data)
        let bambu = try archive.text(at: SlicerSettingsEntries.bambuConfigPath)

        #expect(bambu.contains(#"key="sparse_infill_density" value="15%""#))
        #expect(bambu.contains(#"key="wall_loops" value="4""#))
        #expect(try archive.text(at: SlicerSettingsEntries.prusaConfigPath)
            .contains(#"key="perimeters" value="4""#))
    }

    @Test func `withSlicerSettings wins over a component's own settings for the same key`() async throws {
        let component = Component("Configured", settings: [.infillDensity(15)])
        let platter = Box(10)
            .withSlicerSettings([.infillDensity(80)])
            .inComponent(component)
            .onPlatter()

        let data = try await ModelFileGenerator.build { platter }.data()
        let archive = try ZipArchive(data: data)
        let bambu = try archive.text(at: SlicerSettingsEntries.bambuConfigPath)

        #expect(bambu.contains(#"key="sparse_infill_density" value="80%""#))
        #expect(!bambu.contains(#"value="15%""#))
    }

    @Test func `settings on a passenger don't leak to its host, or the other way around`() async throws {
        // The one this exists for: a die printed with its pips in a lighter infill, each configured
        // independently, riding through packing and grouping as separate volumes of one object.
        let pips = Part("Pips", semantic: .solid)
        let platter = Box(10)
            .withSlicerSettings([.infillDensity(10)])
            .adding {
                Sphere(radius: 1.5)
                    .translated(x: 3, y: 3, z: 8)
                    .withSlicerSettings([.infillDensity(90)])
                    .inPart(pips)
            }
            .inComponent(name: "Die")
            .onPlatter()

        let data = try await ModelFileGenerator.build { platter }.data()
        let archive = try ZipArchive(data: data)
        let bambu = try archive.text(at: SlicerSettingsEntries.bambuConfigPath)

        let object = try #require(bambu.fragments(forTag: "object").first)
        let hostOwn = try #require(object.components(separatedBy: "<part").first)
        #expect(hostOwn.contains(#"key="sparse_infill_density" value="10%""#))
        #expect(!hostOwn.contains(#"value="90%""#))

        let pipsVolume = try #require(object.fragments(forTag: "part").first { $0.contains(#"value="Pips""#) })
        #expect(pipsVolume.contains(#"key="sparse_infill_density" value="90%""#))
        #expect(!pipsVolume.contains(#"value="10%""#))
    }

    @Test func `a nested part's settings don't leak to its host without a platter`() async throws {
        // Without onPlatter there's no stripping to separate host from passenger, so this is the case
        // that actually exercises subtracting a nested part's declarations from its host's.
        let die = Box(10)
            .withSlicerSettings([.infillDensity(10)])
            .adding {
                Sphere(radius: 1.5)
                    .withSlicerSettings([.infillDensity(90)])
                    .inPart(Part("Pips", semantic: .solid))
            }
            .inPart(Part("Die", semantic: .solid))

        let data = try await ModelFileGenerator.build { die }.data()
        let archive = try ZipArchive(data: data)
        let bambu = try archive.text(at: SlicerSettingsEntries.bambuConfigPath)

        let dieObject = try #require(bambu.fragments(forTag: "object").first { $0.contains(#"value="Die""#) })
        #expect(dieObject.contains(#"value="10%""#))
        #expect(!dieObject.contains(#"value="90%""#))

        let pipsObject = try #require(bambu.fragments(forTag: "object").first { $0.contains(#"value="Pips""#) })
        #expect(pipsObject.contains(#"value="90%""#))
        #expect(!pipsObject.contains(#"value="10%""#))
    }

    @Test func `every copy of a component keeps its own settings after packing renames it`() async throws {
        // Mirrors the analogous Component.slicerSettings coverage: withSlicerSettings has to survive
        // packing renaming and copying the part it was declared against.
        let platter = Box(10)
            .withSlicerSettings([.infillDensity(42)])
            .inComponent(name: "Copies", platterOptions: .init(quantity: 3))
            .onPlatter()

        let data = try await ModelFileGenerator.build { platter }.data()
        let archive = try ZipArchive(data: data)
        let bambu = try archive.text(at: SlicerSettingsEntries.bambuConfigPath)

        let objects = bambu.fragments(forTag: "object").filter { $0.contains(#"value="42%""#) }
        #expect(objects.count == 3)
    }
}
