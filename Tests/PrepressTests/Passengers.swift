import Foundation
import Testing
import Cadova
import Zip
@testable import Prepress

/// A die: a cube with its pips as a part of their own, so the slicer can print them in a second color.
/// The motivating case for parts riding along inside a component.
private func die(pips: Part, rotated: Bool = false) -> any Geometry3D {
    let body = Box(10)
        .adding {
            Sphere(radius: 1.5)
                .translated(x: 5, y: 5, z: 8)
                .inPart(pips)
        }
        .inComponent(name: "Die")
    return rotated ? body.rotated(x: 30°, y: 20°) : body
}

struct PassengerTests {
    @Test func `a part inside a component is emitted rather than dropped`() async throws {
        // As a plain part it used to vanish: onPlatter lays out components, and a part isn't one.
        let data = try await ModelFileGenerator.build {
            die(pips: Part("Pips", semantic: .solid)).onPlatter()
        }.data()
        // Both meshes are in the file. The pips are a volume of the die rather than an object of their
        // own, so this looks for meshes rather than for build items.
        let names = try ZipArchive(data: data).meshes().map(\.name)

        #expect(Set(names) == ["Die", "Pips"])
    }

    @Test func `a passenger stays inside its host after the platter moves it`() async throws {
        // The one that catches the stale-transform trap. A component's own catalog isn't transformed
        // when the component is — only the flat top-level one is — so reading passengers from the host
        // yields them at the position they were declared at. The rotation here is what exposes that:
        // without it the two frames coincide and a broken implementation still looks right.
        let data = try await ModelFileGenerator.build {
            die(pips: Part("Pips", semantic: .solid), rotated: true).onPlatter()
        }.data()
        let measured = try ZipArchive(data: data).meshBounds()
        let bounds = Dictionary(
            measured.map { ($0.name, (low: $0.low, high: $0.high)) },
            uniquingKeysWith: { first, _ in first }
        )

        let cube = try #require(bounds["Die"])
        let pips = try #require(bounds["Pips"])

        // The pips sit within the die's own bounds, which is only true if they took the same journey.
        #expect(pips.low.x >= cube.low.x - 0.01 && pips.high.x <= cube.high.x + 0.01, "x \(pips)")
        #expect(pips.low.y >= cube.low.y - 0.01 && pips.high.y <= cube.high.y + 0.01, "y \(pips)")
        #expect(pips.low.z >= cube.low.z - 0.01 && pips.high.z <= cube.high.z + 0.01, "z \(pips)")
    }

    @Test func `every copy of a component brings its own passenger`() async throws {
        // Copies would otherwise share one part identity, merging into a single object spanning several
        // plate positions — and one copy's pose would silently win over the others'.
        let data = try await ModelFileGenerator.build {
            Box(10)
                .adding {
                    Sphere(radius: 1.5).translated(x: 5, y: 5, z: 8)
                        .inPart(Part("Pips", semantic: .solid))
                }
                .inComponent(name: "Die", platterOptions: .init(quantity: 3))
                .onPlatter()
        }.data()
        let archive = try ZipArchive(data: data)
        let measured = try archive.meshBounds()

        #expect(measured.filter { $0.name == "Pips" }.count == 3)
        #expect(measured.filter { $0.name.hasPrefix("Die") }.count == 3)

        // Three objects, each assembled as a unit — a volume has no pose of its own.
        #expect(try archive.assembledPoses().count == 3)

        // Each pair sits together: a pip is always within a die's bounds somewhere.
        var dice: [(low: Vector3D, high: Vector3D)] = []
        var pips: [Vector3D] = []
        for mesh in measured {
            if mesh.name == "Pips" {
                pips.append((mesh.low + mesh.high) / 2)
            } else {
                dice.append((mesh.low, mesh.high))
            }
        }
        for pip in pips {
            let inside = dice.contains { die in
                pip.x >= die.low.x && pip.x <= die.high.x && pip.y >= die.low.y && pip.y <= die.high.y
            }
            #expect(inside, "a pip at \(pip) landed outside every die")
        }
    }

    @Test func `a nested component is laid out once, not twice`() async throws {
        // inComponent ends in a part, so a nested component is a nested part too. It's already laid out
        // as its own piece; riding along as well would emit it twice.
        let data = try await ModelFileGenerator.build {
            Box(10)
                .adding { Box(4).translated(x: 20).inComponent(name: "Inner") }
                .inComponent(name: "Outer")
                .onPlatter()
        }.data()
        let names = try ZipArchive(data: data).modelObjectNames()

        #expect(names.values.filter { $0 == "Inner" }.count == 1)
        #expect(names.values.filter { $0 == "Outer" }.count == 1)
    }

    @Test func `a passenger is kept clear of the neighbours`() async throws {
        // The footprint is taken from the node alone, so a passenger left out of it is one the nester
        // will happily pack a neighbour on top of. This one is a wide disc, far bigger than its host.
        //
        // Round, because the nester rotates pieces: a circle's extent is the same at every angle, so
        // the centres and radii below say exactly where the geometry is, with no slack to hide an
        // overlap in.
        let data = try await ModelFileGenerator.build {
            Box(6).translated(x: -3, y: -3)
                .adding {
                    Cylinder(diameter: 30, height: 4).inPart(Part("Disc", semantic: .solid))
                }
                .inComponent(name: "Host")
                .adding { Cylinder(diameter: 12, height: 6).translated(y: 60).inComponent(name: "Neighbour") }
                .onPlatter()
        }.data()
        let archive = try ZipArchive(data: data)
        let centres = Dictionary(
            try archive.meshBounds().map {
                ($0.name, Vector2D(x: ($0.low.x + $0.high.x) / 2, y: ($0.low.y + $0.high.y) / 2))
            },
            uniquingKeysWith: { first, _ in first }
        )

        let disc = try #require(centres["Disc"])
        let neighbour = try #require(centres["Neighbour"])
        let distance = (disc - neighbour).magnitude

        // 15 + 6 is touching; anything less is the neighbour sitting on top of the disc.
        #expect(distance >= 21, "centres \(distance) mm apart, closer than the two radii")
    }

    @Test func `removingMaterials reaches passengers too`() async throws {
        let data = try await ModelFileGenerator.build {
            Box(10)
                .adding {
                    Sphere(radius: 2).translated(z: 9)
                        .colored(.red)
                        .inPart(Part("Pips", semantic: .solid, color: .blue))
                }
                .inComponent(name: "Die", color: .green)
                .onPlatter(removingMaterials: true)
        }.data()
        let archive = try ZipArchive(data: data)

        // Parts each get their own model file, so check every one of them.
        let paths = ["3D/3dmodel.model"] + (try archive.text(at: "3D/3dmodel.model")
            .fragments(forTag: "component")
            .compactMap { $0.attributeValue("p:path").map { String($0.dropFirst()) } })
        for path in Set(paths) {
            #expect(!(try archive.text(at: path).lowercased().contains("colorgroup")),
                    "a color survived in \(path)")
        }
    }
}

/// A component and the parts riding inside it have to arrive as one object made of several volumes.
/// Anything else is undone on import: a slicer drops each object it loads onto the bed, so a passenger
/// emitted as its own object lands beside its host instead of inside it.
struct PartGroupingTests {
    private func diceArchive(quantity: Int = 1) async throws -> ZipArchive<Data> {
        let data = try await ModelFileGenerator.build {
            Box(10)
                .adding {
                    Sphere(radius: 1.5).translated(x: 3, y: 3, z: 8)
                        .inPart(Part("Pips", semantic: .solid))
                }
                .inComponent(name: "Die", platterOptions: .init(quantity: quantity))
                .onPlatter()
        }.data()
        return try ZipArchive(data: data)
    }

    @Test func `a host and its passenger become one object of two volumes`() async throws {
        let archive = try await diceArchive()
        let model = try archive.text(at: "3D/3dmodel.model")

        // One build item, pointing at an object whose content is components rather than a mesh.
        #expect(model.fragments(forTag: "item").count == 1)
        let parent = try #require(model.fragments(forTag: "object").first { $0.contains("<components>") })
        #expect(parent.fragments(forTag: "component").count == 2)
        #expect(parent.attributeValue("name") == "Die")
    }

    @Test func `each volume is described as a part of its object`() async throws {
        // `<part id>` is matched against the sub-object's own resource id, so the ids here have to be
        // exactly the ones the components reference — otherwise the per-volume naming lands on nothing.
        let archive = try await diceArchive()
        let model = try archive.text(at: "3D/3dmodel.model")
        let config = try archive.text(at: SlicerSettingsEntries.bambuConfigPath)

        let parent = try #require(model.fragments(forTag: "object").first { $0.contains("<components>") })
        let componentIDs = parent.fragments(forTag: "component").compactMap {
            $0.attributeValue("objectid").flatMap(Int.init)
        }
        let partIDs = config.fragments(forTag: "part").compactMap {
            $0.attributeValue("id").flatMap(Int.init)
        }
        #expect(componentIDs.count == 2)
        #expect(Set(partIDs) == Set(componentIDs))
    }

    @Test func `the object and its volumes are named`() async throws {
        // Bambu takes an object's displayed name from this key alone once it has a config block, and
        // the parent object is new — so it isn't in the map built from the parts Cadova wrote.
        let config = try await diceArchive().text(at: SlicerSettingsEntries.bambuConfigPath)
        // Only the object's own metadata: a fragment runs to the next tag of its kind, so it takes in
        // the volumes' metadata too, and a volume is also called "Die".
        let object = try #require(config.fragments(forTag: "object").first)
        let objectOwn = try #require(object.components(separatedBy: "<part").first)

        let objectName = objectOwn.fragments(forTag: "metadata")
            .first { $0.attributeValue("key") == "name" }?.attributeValue("value")
        #expect(objectName == "Die")

        let volumeNames = config.fragments(forTag: "part").compactMap { part in
            part.fragments(forTag: "metadata")
                .first { $0.attributeValue("key") == "name" }?.attributeValue("value")
        }
        #expect(Set(volumeNames) == ["Die", "Pips"])
    }

    @Test func `only the grouped object is assembled`() async throws {
        // A passenger is a volume now, not an object, so it has no pose of its own — its host's carries
        // it. An assemble item for an object that no longer exists would be ignored at best, and the
        // assembly view falls apart if the host's is missing.
        let archive = try await diceArchive(quantity: 2)
        let config = try archive.text(at: SlicerSettingsEntries.bambuConfigPath)
        let model = try archive.text(at: "3D/3dmodel.model")

        let itemIDs = Set(model.fragments(forTag: "item").compactMap {
            $0.attributeValue("objectid").flatMap(Int.init)
        })
        #expect(itemIDs.count == 2, "one object per die")

        let assembled = Set(config.fragments(forTag: "assemble_item").compactMap {
            $0.attributeValue("object_id").flatMap(Int.init)
        })
        #expect(assembled == itemIDs)
    }

    @Test func `an ungrouped part is left exactly as it was`() async throws {
        // Nothing about a model without passengers should change: no components, no parts, one object
        // per component as before.
        let data = try await ModelFileGenerator.build {
            Box(10).inComponent(name: "A")
                .adding { Box(10).translated(x: 30).inComponent(name: "B") }
                .onPlatter()
        }.data()
        let archive = try ZipArchive(data: data)
        let model = try archive.text(at: "3D/3dmodel.model")

        #expect(!model.contains("<components>"))
        #expect(model.fragments(forTag: "item").count == 2)
        #expect(!(try archive.text(at: SlicerSettingsEntries.bambuConfigPath).contains("<part ")))
    }
}
