import Foundation
import Testing
import Cadova
@testable import Sprue

struct PlatterTests {
    @Test func `platter orients a component that contains a nested part`() async throws {
        let main = Component("Main", upDirection: .right)
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
            .inComponent(main)
            .rotated(x: 90°)
            .onPlatter(separatingParts: false)
            .evaluating { geometry, evaluator in
                let parts = await evaluator.parts(of: geometry)
                capture.bounds = await evaluator.bounds(of: parts[main.part]!)
                return geometry
            }

        _ = try await ModelFileGenerator.build {
            platter
        }

        #expect(abs((capture.bounds?.size.z ?? 0) - 10) < 1e-6)
    }

    @Test func `platter skips parts that aren't components`() async throws {
        // A plain part — even one with a Cadova natural up direction — is not a Sprue component, so
        // the platter leaves it out rather than dropping it on the bed in an arbitrary orientation.
        let part = Part("Plain")
        let capture = BoundsCapture()

        let platter = Box(x: 10, y: 20, z: 30)
            .definingNaturalUpDirection(.up)
            .inPart(part)
            .rotated(x: 90°)
            .onPlatter(separatingParts: false)
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
        let outer = Component("Outer", upDirection: .up)
        let nested = Component("Nested", upDirection: .up)
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
            .onPlatter(separatingParts: false)
            .evaluating { geometry, evaluator in
                let parts = await evaluator.parts(of: geometry)
                capture.bounds = await evaluator.bounds(of: parts[nested.part]!)
                return geometry
            }

        _ = try await ModelFileGenerator.build {
            platter
        }

        #expect(abs((capture.bounds?.size.z ?? 0) - 5) < 1e-6)
    }

    @Test func `platter does not mirror a part across its declared up direction`() async throws {
        let component = Component("Asymmetric", upDirection: .up)
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
            .onPlatter(separatingParts: false)
            .evaluating { geometry, evaluator in
                let parts = await evaluator.parts(of: geometry)
                let partGeometry = parts[component.part]!
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

    @Test func `platter packs reoriented parts without overlap in a rotated assembly`() async throws {
        // Regression: a part whose declared up direction needs reorienting (here a flat disc whose
        // axis is tipped sideways by the enclosing assembly's `rotated(x: 90°)`) must have its
        // packing footprint computed from the *same* oriented body that is finally placed. When the
        // footprint was built from a separately-resolved orientation, the disc was packed as if
        // standing on edge (a narrow footprint) but laid flat when placed — so the flat disc spilled
        // over its neighbor. The two solid parts must not intersect after packing.
        let disc = Component("Disc", upDirection: .up)
        let block = Component("Block", upDirection: .up)
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
                let discGeometry = parts[disc.part]!
                let blockGeometry = parts[block.part]!
                capture.partsOverlap = !(await evaluator.isEmpty(discGeometry.intersecting(blockGeometry)))
                return geometry
            }

        _ = try await ModelFileGenerator.build {
            platter
        }

        #expect(capture.partsOverlap == false)
    }
}
