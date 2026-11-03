import Foundation
import Testing
import Cadova
@testable import Prepress

private extension ComponentTag {
    static let wheels = ComponentTag("Wheels")
    static let flexible = ComponentTag("Flexible")
    static let absent = ComponentTag("Absent")
}

struct PlatterSelectionTests {
    /// The names of the parts a platter of this assembly emits under a selection.
    private func partNames(
        only: Set<ComponentTag>? = nil,
        excluding: Set<ComponentTag> = [],
        of assembly: any Geometry3D
    ) async throws -> Set<String> {
        let capture = BoundsCapture()
        let platter = assembly
            .onPlatter(only: only, excluding: excluding)
            .evaluating { geometry, evaluator in
                capture.partNames = Set(await evaluator.parts(of: geometry).keys.map(\.name))
                return geometry
            }
        _ = try await ModelFileGenerator.build { platter }
        return try #require(capture.partNames)
    }

    private var assembly: any Geometry3D {
        Box(10).inComponent(name: "Rim", tags: [.wheels])
            .adding {
                Box(10).translated(x: 40).inComponent(name: "Tire", tags: [.wheels, .flexible])
                Box(10).translated(x: 80).inComponent(name: "Bushing", tags: [.flexible])
                Box(10).translated(x: 120).inComponent(name: "Chassis")
            }
    }

    @Test func `no selection takes every component`() async throws {
        #expect(try await partNames(of: assembly) == ["Rim", "Tire", "Bushing", "Chassis"])
    }

    @Test func `only takes components with any of the tags`() async throws {
        #expect(try await partNames(only: [.wheels], of: assembly) == ["Rim", "Tire"])
        #expect(try await partNames(only: [.wheels, .flexible], of: assembly) == ["Rim", "Tire", "Bushing"])
    }

    @Test func `excluding is a catch-all that keeps untagged components`() async throws {
        #expect(try await partNames(excluding: [.wheels], of: assembly) == ["Bushing", "Chassis"])
    }

    @Test func `excluding wins over only`() async throws {
        #expect(try await partNames(only: [.wheels], excluding: [.flexible], of: assembly) == ["Rim"])
    }

    @Test func `a nested component is selected by its own tags`() async throws {
        let assembly = Box(10)
            .adding { Box(4).translated(z: 10).inComponent(name: "Inner", tags: [.flexible]) }
            .inComponent(name: "Outer", tags: [.wheels])

        #expect(try await partNames(only: [.wheels], of: assembly) == ["Outer"])
        #expect(try await partNames(only: [.flexible], of: assembly) == ["Inner"])
    }

    @Test func `a plain part follows the component it's declared in`() async throws {
        let assembly = Box(10)
            .adding { Box(4).translated(z: 10).inPart(name: "Pips") }
            .inComponent(name: "Die", tags: [.wheels])

        #expect(try await partNames(only: [.wheels], of: assembly) == ["Die", "Pips"])
        #expect(try await partNames(excluding: [.wheels], of: assembly).isEmpty)
    }

    @Test func `numbering counts only what the platter holds`() async throws {
        let wheel = Component("Wheel", tags: [.wheels])
        let spare = Component("Wheel", tags: [.flexible], platterOptions: .init(quantity: 2))
        let assembly = Box(10).inComponent(wheel)
            .adding { Box(10).translated(x: 40).inComponent(spare) }

        #expect(try await partNames(only: [.wheels], of: assembly) == ["Wheel"])
        #expect(try await partNames(only: [.flexible], of: assembly) == ["Wheel 1", "Wheel 2"])
    }

    @Test func `an empty platter still builds`() async throws {
        #expect(try await partNames(only: [], of: assembly).isEmpty)
    }

    @Test func `problems name unknown tags and empty platters`() {
        let rim = Component("Rim", tags: [.wheels])
        let chassis = Component("Chassis")

        // Nothing was asked for, so nothing can be wrong, even with no components at all.
        #expect(ComponentSelection(only: nil, excluding: []).problems(in: []).isEmpty)
        #expect(ComponentSelection(only: [.wheels], excluding: []).problems(in: [rim, chassis]).isEmpty)

        let unknown = ComponentSelection(only: nil, excluding: [.absent]).problems(in: [rim, chassis])
        #expect(unknown.count == 1)
        #expect(unknown.first?.contains("Absent") == true)

        // An unknown tag being all that was asked for is both things at once.
        #expect(ComponentSelection(only: [.absent], excluding: []).problems(in: [rim, chassis]).count == 2)
        #expect(ComponentSelection(only: [], excluding: []).problems(in: [rim, chassis]).count == 1)
    }
}

struct PlatterTests {
    @Test func `platter orients a component that contains a nested part`() async throws {
        let main = Component("Main", platterOptions: .init(separateSolids: false))
        let nestedPart = Part("Nested")
        let capture = BoundsCapture()

        // A component whose body contains a (plain) nested part must still orient by its own up
        // direction — the nested part is stripped from the component's body, and reading the
        // component's own declaration isn't shadowed by it.
        let platter = Box(x: 10, y: 20, z: 30)
            .adding {
                Box(2)
                    .inPart(nestedPart)
            }
            .inComponent(main, upDirection: .right)
            .rotated(x: 90°)
            .onPlatter()
            .evaluating { geometry, evaluator in
                let parts = await evaluator.parts(of: geometry)
                capture.bounds = await evaluator.bounds(of: parts.first { $0.key.name == "Main" }!.value)
                return geometry
            }

        _ = try await ModelFileGenerator.build {
            platter
        }

        #expect(abs((capture.bounds?.size.z ?? 0) - 10) < 1e-6)
    }

    @Test func `platter skips parts that aren't components`() async throws {
        // A plain part — even one with a Cadova natural up direction — is not a Prepress component, so
        // the platter leaves it out rather than dropping it on the bed in an arbitrary orientation.
        let part = Part("Plain")
        let capture = BoundsCapture()

        let platter = Box(x: 10, y: 20, z: 30)
            .definingNaturalUpDirection(.up)
            .inPart(part)
            .rotated(x: 90°)
            .onPlatter()
            .evaluating { geometry, evaluator in
                let parts = await evaluator.parts(of: geometry)
                capture.partWasPacked = parts[part] != nil
                return geometry
            }

        _ = try await ModelFileGenerator.build {
            platter
        }

        #expect(capture.partWasPacked == false)
    }

    @Test func `nested component is packed with its own up direction`() async throws {
        let outer = Component("Outer", platterOptions: .init(separateSolids: false))
        let nested = Component("Nested", platterOptions: .init(separateSolids: false))
        let capture = BoundsCapture()

        // A component nested inside another component is packed on its own, oriented by its own
        // declared up direction (like the rc1 hub-bearing-house-top inside the hub).
        let platter = Box(x: 10, y: 10, z: 10)
            .adding {
                Box(x: 8, y: 2, z: 5)
                    .inComponent(nested)
            }
            .inComponent(outer)
            .rotated(x: 90°)
            .onPlatter()
            .evaluating { geometry, evaluator in
                let parts = await evaluator.parts(of: geometry)
                capture.bounds = await evaluator.bounds(of: parts.first { $0.key.name == "Nested" }!.value)
                return geometry
            }

        _ = try await ModelFileGenerator.build {
            platter
        }

        #expect(abs((capture.bounds?.size.z ?? 0) - 5) < 1e-6)
    }

    @Test func `platter does not mirror a part across its declared up direction`() async throws {
        let component = Component("Asymmetric", platterOptions: .init(separateSolids: false))
        let capture = BoundsCapture()

        let platter = Box(x: 10, y: 10, z: 10)
            .aligned(at: .minZ)
            .adding {
                Box(x: 3, y: 3, z: 2)
                    .aligned(at: .minX, .minZ)
                    .translated(x: 4.5, z: 10)
            }
            .inComponent(component)
            .rotated(x: 90°)
            .onPlatter()
            .evaluating { geometry, evaluator in
                let parts = await evaluator.parts(of: geometry)
                let partGeometry = parts.first { $0.key.name == "Asymmetric" }!.value
                let bounds = await evaluator.bounds(of: partGeometry)!
                capture.bounds = bounds
                var bottomHits = 0
                var topHits = 0
                for ix in 0 ..< 9 {
                    for iy in 0 ..< 9 {
                        let x = bounds.minimum.x + bounds.size.x * (Double(ix) + 0.5) / 9
                        let y = bounds.minimum.y + bounds.size.y * (Double(iy) + 0.5) / 9
                        let segment = LineSegment3D(from: [x, y, -1], to: [x, y, bounds.maximum.z + 1])
                        let zs = await evaluator.surfaces(of: partGeometry, along: segment)
                            .map(\.position.z)
                        if let minZ = zs.min(), abs(minZ) < 1e-6 {
                            bottomHits += 1
                        }
                        if let maxZ = zs.max(), abs(maxZ - bounds.maximum.z) < 1e-6 {
                            topHits += 1
                        }
                    }
                }
                capture.bottomSurfaceHitCount = bottomHits
                capture.topSurfaceHitCount = topHits
                return geometry
            }

        _ = try await ModelFileGenerator.build {
            platter
        }

        #expect(abs((capture.bounds?.size.z ?? 0) - 12) < 1e-6)
        #expect((capture.bottomSurfaceHitCount ?? 0) > (capture.topSurfaceHitCount ?? 0))
    }

    @Test func `each declaration of one component is oriented on its own`() async throws {
        // Regression: two bodies of the same component, tilted differently in the assembly. The
        // orientation used to be captured once per *part*, last declaration winning, and applied to the
        // whole merged geometry — so every body but one came out of the platter still tilted. Each
        // declaration now emits into its own part and carries its own frame.
        let tube = Component("Tube")
        let capture = BoundsCapture()

        let platter = Stack(.x, spacing: 1) {
            Cylinder(diameter: 5, height: 50)
                .inComponent(tube)
                .rotated(x: 20°)

            Cylinder(diameter: 6, height: 30)
                .inComponent(tube)
                .rotated(y: -15°)
        }
        .onPlatter()
        .evaluating { geometry, evaluator in
            var sizes: [String: Vector3D] = [:]
            for (part, partGeometry) in await evaluator.parts(of: geometry) {
                sizes[part.name] = await evaluator.bounds(of: partGeometry)?.size
            }
            capture.sizes = sizes
            return geometry
        }

        _ = try await ModelFileGenerator.build { platter }

        // Both stand upright: full length in Z, and a footprint no wider than the diameter.
        let sizes = try #require(capture.sizes)
        #expect(sizes.count == 2)
        for (name, size) in sizes {
            let diameter = abs(size.z - 50) < 1e-3 ? 5.0 : 6.0
            #expect(abs(size.z - (diameter == 5 ? 50 : 30)) < 1e-3, "\(name) is \(size.z) tall")
            #expect(size.x < diameter + 0.1 && size.y < diameter + 0.1, "\(name) footprint is \(size)")
        }
    }

    @Test func `an empty component is left off the platter`() async throws {
        // Regression: a component whose body comes out empty (here a rectangle rounded away entirely)
        // was asked for its first separated solid, which doesn't exist, and the build crashed. Both
        // the separated and the whole path must just leave it out.
        let capture = BoundsCapture()

        let platter = Rectangle(x: 14, y: 40).rounded(radius: 7).extruded(height: 5)
            .inComponent(name: "Vanished")
            .adding {
                Rectangle(x: 14, y: 40).rounded(radius: 7).extruded(height: 5)
                    .inComponent(name: "Vanished whole", platterOptions: .init(separateSolids: false))
                Box(10).translated(x: 40).inComponent(name: "Kept")
            }
            .onPlatter()
            .evaluating { geometry, evaluator in
                capture.partNames = Set(await evaluator.parts(of: geometry).keys.map(\.name))
                return geometry
            }

        _ = try await ModelFileGenerator.build { platter }

        #expect(capture.partNames == ["Kept"])
    }

    @Test func `solid separation is decided per component`() async throws {
        // The point of moving this onto the component: one component can keep its solids together as a
        // rigid unit while another in the same platter is split apart. As a single option on
        // onPlatter it was all or nothing.
        let split = Component("Split")
        let whole = Component("Whole", platterOptions: .init(separateSolids: false))
        let capture = BoundsCapture()

        let platter = Box(10)
            .adding { Box(10).translated(x: 40) }
            .inComponent(split)
            .adding {
                Box(10).translated(y: 60)
                    .adding { Box(10).translated(x: 40, y: 60) }
                    .inComponent(whole)
            }
            .onPlatter()
            .evaluating { geometry, evaluator in
                let parts = await evaluator.parts(of: geometry)
                // The split component becomes two numbered parts; the whole one stays single.
                capture.partNames = Set(parts.keys.map(\.name))
                return geometry
            }

        _ = try await ModelFileGenerator.build { platter }

        let names = try #require(capture.partNames)
        #expect(names.contains("Split 1") && names.contains("Split 2"))
        #expect(names.contains("Whole"))
    }

    @Test func `platter packs reoriented parts without overlap in a rotated assembly`() async throws {
        // Regression: a part whose declared up direction needs reorienting (here a flat disc whose
        // axis is tipped sideways by the enclosing assembly's `rotated(x: 90°)`) must have its
        // packing footprint computed from the *same* oriented body that is finally placed. When the
        // footprint was built from a separately-resolved orientation, the disc was packed as if
        // standing on edge (a narrow footprint) but laid flat when placed — so the flat disc spilled
        // over its neighbor. The two solid parts must not intersect after packing.
        let disc = Component("Disc")
        let block = Component("Block")
        let capture = BoundsCapture()

        let platter = Cylinder(diameter: 120, height: 50)
            .inComponent(disc)
            .adding {
                Box(x: 40, y: 16, z: 30)
                    .aligned(at: .centerX)
                    .translated(y: 9)
                    .inComponent(block)
                    .translated(z: 80)
            }
            .translated(y: -20, z: -40)
            .definingNaturalUpDirection(.positiveZ)
            .rotated(x: 90°)
            .onPlatter()
            .withComponentSpacing(4)
            .evaluating { geometry, evaluator in
                let parts = await evaluator.parts(of: geometry)
                let discGeometry = parts.first { $0.key.name == "Disc" }!.value
                let blockGeometry = parts.first { $0.key.name == "Block" }!.value
                capture.partsOverlap = !(await evaluator.isEmpty(discGeometry.intersecting(blockGeometry)))
                return geometry
            }

        _ = try await ModelFileGenerator.build {
            platter
        }

        #expect(capture.partsOverlap == false)
    }
}
