import Foundation
import Testing
import Cadova
@testable import Fabricate

/// Independent separating-axis overlap test, kept separate from the nester's own NFP math so the tests
/// don't merely re-assert the production code. Returns true only when the two convex polygons share
/// positive area; merely touching edges/vertices is not an overlap.
private func overlaps(_ a: ConvexPolygon, _ b: ConvexPolygon, epsilon: Double = 1e-6) -> Bool {
    func axes(of polygon: ConvexPolygon) -> [Vector2D] {
        polygon.vertices.indices.map { i in
            let p = polygon.vertices[i]
            let q = polygon.vertices[(i + 1) % polygon.vertices.count]
            let edge = q - p
            return Vector2D(x: -edge.y, y: edge.x) // outward/inward normal
        }
    }

    for axis in axes(of: a) + axes(of: b) {
        let aProj = a.vertices.map { $0 ⋅ axis }
        let bProj = b.vertices.map { $0 ⋅ axis }
        let aMin = aProj.min()!, aMax = aProj.max()!
        let bMin = bProj.min()!, bMax = bProj.max()!
        // A gap on any axis (allowing a touching tolerance) means no overlap.
        if aMax <= bMin + epsilon || bMax <= aMin + epsilon {
            return false
        }
    }
    return true
}

private func place(_ polygon: ConvexPolygon, with transform: Transform2D) -> ConvexPolygon {
    polygon.transformed(transform)
}

@Test func nestingProducesNoOverlaps() {
    let polygons: [ConvexPolygon] = [
        ConvexPolygon(hullOf: [[0, 0], [40, 0], [40, 40], [0, 40]]),       // square
        ConvexPolygon(hullOf: [[0, 0], [60, 0], [60, 12], [0, 12]]),       // long rectangle
        ConvexPolygon(hullOf: [[0, 0], [30, 0], [15, 26]]),                // triangle
        ConvexPolygon(hullOf: [[0, 0], [20, 0], [20, 50], [0, 50]]),       // tall rectangle
        ConvexPolygon(hullOf: [[0, 0], [18, 0], [25, 18], [9, 28], [-3, 14]]), // pentagon
    ]

    let placements = nest(polygons, rotationCount: 4)
    #expect(placements.count == polygons.count)

    let placed = zip(polygons, placements).map { place($0, with: $1) }
    for i in placed.indices {
        for j in (i + 1) ..< placed.count {
            #expect(!overlaps(placed[i], placed[j]), "pieces \(i) and \(j) overlap")
        }
    }
}

@Test func packedFootprintIsCompact() {
    // Eight identical squares should pack into a roughly square block, far tighter than laying them
    // out in a single row.
    let square = ConvexPolygon(hullOf: [[0, 0], [20, 0], [20, 20], [0, 20]])
    let polygons = Array(repeating: square, count: 8)

    let placements = nest(polygons, rotationCount: 4)
    let placed = zip(polygons, placements).map { place($0, with: $1) }

    var lo = placed[0].boundingBox.min, hi = placed[0].boundingBox.max
    for poly in placed.dropFirst() {
        lo = Vector2D.min(lo, poly.boundingBox.min)
        hi = Vector2D.max(hi, poly.boundingBox.max)
    }
    let size = hi - lo
    let packedArea = size.x * size.y
    let totalPieceArea = polygons.reduce(0.0) { $0 + $1.area }

    // Tight packing should waste little space; a single row would be ~8x worse than the pieces' area.
    #expect(packedArea <= totalPieceArea * 1.6)

    for i in placed.indices {
        for j in (i + 1) ..< placed.count {
            #expect(!overlaps(placed[i], placed[j]), "pieces \(i) and \(j) overlap")
        }
    }
}

@Test func circumscribedContainsOriginalWithinBudget() {
    // A finely tessellated circle (the kind projected cylinders/spheres produce) must collapse to a
    // small vertex count while still fully containing the original.
    let circlePoints = (0 ..< 360).map { i -> Vector2D in
        let a = Angle(turns: Double(i) / 360)
        return Vector2D(x: 20 * cos(a), y: 20 * sin(a))
    }
    let original = ConvexPolygon(hullOf: circlePoints)
    let simplified = original.circumscribed(directionCount: 24)

    #expect(simplified.vertices.count <= 24)
    // Outer approximation: every original vertex stays inside (boundary tolerance).
    for v in original.vertices {
        #expect(simplified.strictlyContains(v) || isOnOrInside(v, simplified))
    }
}

private func isOnOrInside(_ point: Vector2D, _ polygon: ConvexPolygon, epsilon: Double = 1e-6) -> Bool {
    for i in polygon.vertices.indices {
        let a = polygon.vertices[i]
        let b = polygon.vertices[(i + 1) % polygon.vertices.count]
        let cross = (b.x - a.x) * (point.y - a.y) - (b.y - a.y) * (point.x - a.x)
        if cross < -epsilon { return false }
    }
    return true
}

@Test func packingEnvironmentDefaultsAndRoundTrip() {
    // Defaults when unset.
    #expect(EnvironmentValues().packingMargin == 1)
    #expect(EnvironmentValues().packingRotationCount == 4)

    // Round-trip through the EnvironmentValues setters.
    #expect(EnvironmentValues().withPackingMargin(2.5).packingMargin == 2.5)
    #expect(EnvironmentValues().withPackingRotationCount(8).packingRotationCount == 8)
}

@Test func componentDataResultElement() {
    // Defaults to "not a component"; combining is last-wins so an outermost declaration takes precedence,
    // and a nil (plain part) never clobbers a real value.
    #expect(ComponentData().value == nil)

    let inner = ComponentData(.init(upDirection: .up, transform: .identity, quantity: 2))
    let outer = ComponentData(.init(upDirection: .down, transform: .identity, quantity: 7))
    #expect(ComponentData(combining: [inner, outer]).value?.quantity == 7)
    #expect(ComponentData(combining: [inner, ComponentData()]).value?.quantity == 2)
}

@Test func asComponentOverloadsCompile() {
    _ = Box(1)
        .asComponent(name: "Sideways", upDirection: .right)
    _ = Box(1)
        .asComponent(name: "Many", quantity: 3)
    _ = Box(1)
        .asComponent(Part("Custom"), upDirection: .forward)
    _ = Box(1)
        .asComponent(Part("Repeated"), quantity: 2)
}

@Test func platterOrientsComponentWithNestedPart() async throws {
    let mainPart = Part("Main")
    let nestedPart = Part("Nested")
    let capture = BoundsCapture()

    // A component whose body contains a (plain) nested part must still orient by its own up direction —
    // the nested part is stripped from the component's body, and reading the component's own declaration
    // isn't shadowed by it.
    let platter = Box(x: 10, y: 20, z: 30)
        .adding {
            Box(2)
                .inPart(nestedPart)
        }
        .asComponent(mainPart, upDirection: .right)
        .rotated(x: 90°)
        .onPlatter(separatingParts: false)
        .evaluating { geometry, evaluator in
            let parts = await evaluator.parts(of: geometry)
            capture.bounds = await evaluator.bounds(of: parts[mainPart]!)
            return geometry
        }

    _ = try await ModelFileGenerator.build {
        platter
    }

    #expect(abs((capture.bounds?.size.z ?? 0) - 10) < 1e-6)
}

@Test func platterSkipsPartsThatArentComponents() async throws {
    // A plain part — even one with a Cadova natural up direction — is not a Fabricate component, so the
    // platter leaves it out rather than dropping it on the bed in an arbitrary orientation.
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

@Test func nestedComponentIsPackedWithItsOwnUpDirection() async throws {
    let outerPart = Part("Outer")
    let nestedPart = Part("Nested")
    let capture = BoundsCapture()

    // A component nested inside another component is packed on its own, oriented by its own declared up
    // direction (like the rc1 hub-bearing-house-top inside the hub).
    let platter = Box(x: 10, y: 10, z: 10)
        .adding {
            Box(x: 8, y: 2, z: 5)
                .asComponent(nestedPart, upDirection: .up)
        }
        .asComponent(outerPart, upDirection: .up)
        .rotated(x: 90°)
        .onPlatter(separatingParts: false)
        .withPackingRotationCount(1)
        .evaluating { geometry, evaluator in
            let parts = await evaluator.parts(of: geometry)
            capture.bounds = await evaluator.bounds(of: parts[nestedPart]!)
            return geometry
        }

    _ = try await ModelFileGenerator.build {
        platter
    }

    #expect(abs((capture.bounds?.size.z ?? 0) - 5) < 1e-6)
}

@Test func platterDoesNotMirrorPartAcrossDeclaredUpDirection() async throws {
    let part = Part("Asymmetric")
    let capture = BoundsCapture()

    let platter = Box(x: 10, y: 10, z: 10)
        .aligned(at: .minZ)
        .adding {
            Box(x: 3, y: 3, z: 2)
                .aligned(at: .minX, .minZ)
                .translated(x: 4.5, z: 10)
        }
        .asComponent(part, upDirection: .up)
        .rotated(x: 90°)
        .onPlatter(separatingParts: false)
        .withPackingRotationCount(1)
        .evaluating { geometry, evaluator in
            let parts = await evaluator.parts(of: geometry)
            let partGeometry = parts[part]!
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

@Test func convexHullCleansCollinearAndDuplicatePoints() {
    // Duplicates and a midpoint on the bottom edge should collapse to the four corners.
    let poly = ConvexPolygon(hullOf: [[0, 0], [5, 0], [10, 0], [10, 10], [0, 10], [0, 10], [0, 0]])
    #expect(poly.vertices.count == 4)
    #expect(abs(poly.area - 100) < 1e-9)
}

/// A finely tessellated, high-aspect-ratio outline — the shape of a long thin part like the rc1 "Hub
/// bearing house top". Circumscribing it (below) is where coincident corners arise.
private func thinFootprintPoints(halfWidth: Double = 30, halfHeight: Double = 2, count: Int = 120) -> [Vector2D] {
    (0 ..< count).map { i in
        let a = Angle(turns: Double(i) / Double(count))
        return Vector2D(x: halfWidth * cos(a), y: halfHeight * sin(a))
    }
}

@Test func circumscribedThinFootprintHasNoZeroLengthEdges() {
    // `circumscribed` simplifies a many-vertex hull by intersecting evenly spaced supporting lines. For a
    // long thin footprint, several adjacent supporting lines touch the same near-flat edge and meet in
    // near-coincident corners. Those must not survive as zero-length edges: a zero-length edge makes
    // `strictlyContains` reject every point and desyncs the no-fit-polygon merge, so the nester places
    // the piece overlapping its neighbours (the rc1 "Hub bearing house top" / tire overlap).
    let footprint = ConvexPolygon(hullOf: thinFootprintPoints()).circumscribed(directionCount: 24)
    for i in footprint.vertices.indices {
        let a = footprint.vertices[i]
        let b = footprint.vertices[(i + 1) % footprint.vertices.count]
        #expect((a - b).magnitude > 1e-6, "zero-length edge between \(a) and \(b)")
    }
}

@Test func nestingDoesNotOverlapThinCircumscribedFootprint() {
    // Regression for the rc1 Wheel platter: a thin part packed beside a large disc must not be placed on
    // top of it. The thin footprint's circumscribed corners used to collapse into zero-length edges,
    // breaking the nester's overlap test.
    let disc = ConvexPolygon(hullOf: (0 ..< 64).map { i -> Vector2D in
        let a = Angle(turns: Double(i) / 64)
        return Vector2D(x: 60 * cos(a), y: 60 * sin(a))
    }).circumscribed(directionCount: 24)
    let thin = ConvexPolygon(hullOf: thinFootprintPoints()).circumscribed(directionCount: 24)

    let polygons = [disc, thin]
    let placements = nest(polygons, rotationCount: 4)
    let placed = zip(polygons, placements).map { place($0, with: $1) }
    for i in placed.indices {
        for j in (i + 1) ..< placed.count {
            #expect(!overlaps(placed[i], placed[j]), "pieces \(i) and \(j) overlap")
        }
    }
}

private final class BoundsCapture: @unchecked Sendable {
    var bounds: BoundingBox3D?
    var bottomSurfaceHitCount: Int?
    var topSurfaceHitCount: Int?
    var partsOverlap: Bool?
    var partWasPacked: Bool?
}

@Test func platterPacksReorientedPartsWithoutOverlapInRotatedAssembly() async throws {
    // Regression: a part whose declared up direction needs reorienting (here a flat disc whose axis is
    // tipped sideways by the enclosing assembly's `rotated(x: 90°)`) must have its packing footprint
    // computed from the *same* oriented body that is finally placed. When the footprint was built from a
    // separately-resolved orientation, the disc was packed as if standing on edge (a narrow footprint)
    // but laid flat when placed — so the flat disc spilled over its neighbor. The two solid parts must
    // not intersect after packing.
    let disc = Part("Disc")
    let block = Part("Block")
    let capture = BoundsCapture()

    let platter = Cylinder(diameter: 120, height: 50)
        .asComponent(disc, upDirection: .up)
        .adding {
            Box(x: 40, y: 16, z: 30)
                .aligned(at: .centerX)
                .translated(y: 9)
                .asComponent(block, upDirection: .up)
                .translated(z: 80)
        }
        .translated(y: -20, z: -40)
        .definingNaturalUpDirection(.positiveZ)
        .rotated(x: 90°)
        .onPlatter()
        .withPackingMargin(2)
        .evaluating { geometry, evaluator in
            let parts = await evaluator.parts(of: geometry)
            let discGeometry = parts[disc]!
            let blockGeometry = parts[block]!
            capture.partsOverlap = !(await evaluator.isEmpty(discGeometry.intersecting(blockGeometry)))
            return geometry
        }

    _ = try await ModelFileGenerator.build {
        platter
    }

    #expect(capture.partsOverlap == false)
}

@Test func nestingToleratesEmptyAndDegenerateFootprints() {
    // An empty footprint (e.g. from an empty component) must not crash bounding-box math.
    let empty = ConvexPolygon(hullOf: [])
    #expect(empty.vertices.isEmpty)
    #expect(empty.boundingBox.min == .zero && empty.boundingBox.max == .zero)

    // Nesting a mix of empty, degenerate (a segment) and normal footprints must not crash.
    let polygons = [
        empty,
        ConvexPolygon(hullOf: [[0, 0], [5, 0]]),
        ConvexPolygon(hullOf: [[0, 0], [20, 0], [20, 20], [0, 20]]),
    ]
    let placements = nest(polygons, rotationCount: 4)
    #expect(placements.count == polygons.count)
}

@Test func bambuModelSettingsConfigFormatsEntriesAndEscapesValues() throws {
    let part = Part("Widget")
    let xml = try bambuModelSettingsConfig(
        for: [(part, [.sparseInfillDensity: "15%", .wallLoops: "A & B <ok>"])],
        objectID: { _ in 42 }
    )
    let string = String(decoding: xml, as: UTF8.self)

    #expect(string.contains(#"<object id="42">"#))
    #expect(string.contains(#"key="sparse_infill_density" value="15%""#))
    // `>` isn't required to be escaped in XML attribute values, and Nodal (via pugixml) doesn't.
    #expect(string.contains(#"key="wall_loops" value="A &amp; B &lt;ok>""#))
}

@Test func bambuModelSettingsConfigSkipsPartsWithUnresolvableObjectID() throws {
    // A part the caller can't resolve an id for (shouldn't happen for anything actually packed) is
    // skipped rather than emitting a malformed <object id="..."> entry.
    let part = Part("Orphan")
    let xml = try bambuModelSettingsConfig(for: [(part, [.wallLoops: "3"])], objectID: { _ in nil })
    let string = String(decoding: xml, as: UTF8.self)

    #expect(!string.contains("<object"))
}

@Test func bambuModelSettingsConfigMergesMultipleEntriesResolvingToTheSameID() throws {
    // Regression: asComponent's own declaration and onPlatter's re-declaration against the final
    // packed part both resolve to the same id whenever packing didn't rename or copy the part (the
    // common quantity == 1, removingMaterials == false case) — this must produce one merged <object>
    // block, not two duplicate ones.
    let partA = Part("A")
    let partB = Part("B") // a distinct Part instance that still resolves to the same object id as A
    let xml = try bambuModelSettingsConfig(
        for: [(partA, [.wallLoops: "3"]), (partB, [.sparseInfillDensity: "20%"])],
        objectID: { _ in 7 }
    )
    let string = String(decoding: xml, as: UTF8.self)

    #expect(string.components(separatedBy: "<object").count == 2) // one split point == one <object> block
    #expect(string.contains(#"key="wall_loops" value="3""#))
    #expect(string.contains(#"key="sparse_infill_density" value="20%""#))
}

@Test func infillPatternRawValuesMatchBambuStudioNotTheirLabels() throws {
    // Regression: Bambu Studio's raw config value for the pattern labeled "Rectilinear" in its UI is,
    // confusingly, "zig-zag" — and a *separate* raw value "zigzag" (no hyphen) exists for the actual
    // "Zig Zag" pattern. Getting these backwards would silently write the wrong pattern.
    #expect(InfillPattern.rectilinear.rawValue == "zig-zag")
    #expect(InfillPattern.zigzag.rawValue == "zigzag")

    let part = Part("Widget")
    let xml = try bambuModelSettingsConfig(
        for: [(part, [.sparseInfillPattern: InfillPattern.rectilinear.rawValue])],
        objectID: { _ in 1 }
    )
    let string = String(decoding: xml, as: UTF8.self)
    #expect(string.contains(#"key="sparse_infill_pattern" value="zig-zag""#))
}

@Test func slicerSettingTypedFactoriesProduceExpectedRawValues() {
    #expect(SlicerSetting.enableSupport(true).value == "1")
    #expect(SlicerSetting.enableSupport(false).value == "0")
    #expect(SlicerSetting.wallLoops(3).value == "3")
    #expect(SlicerSetting.sparseInfillDensity(15).value == "15%")
    #expect(SlicerSetting.layerHeight(0.2).value == "0.2")
    #expect(SlicerSetting.seamPosition(.aligned).value == "aligned")
    #expect(SlicerSetting.brimType(.outerOnly).value == "outer_only")
    #expect(SlicerSetting.supportStyle(.treeOrganic).value == "tree_organic")
    #expect(SlicerSetting.supportBasePattern(.rectilinearGrid).value == "rectilinear-grid")
    #expect(SlicerSetting.wallSequence(.innerOuterInner).value == "inner-outer-inner wall")
    #expect(SlicerSetting.ironingType(.noIroning).value == "no ironing")

    // All of these route through the same underlying key, whichever factory is used.
    #expect(SlicerSetting.enableSupport(true).key == .enableSupport)
    #expect(SlicerSetting.raw(.enableSupport, "1").key == .enableSupport)
}

@Test func forkExtensionFactoriesProduceExpectedRawValues() {
    // OrcaSlicer extension.
    #expect(SlicerSetting.zContouringEnabled(true).value == "1")
    #expect(SlicerSetting.zContouringEnabled(true).key == .zContouringEnabled)
    #expect(SlicerSetting.infillAnchor(50).value == "50.0")
    #expect(SlicerSetting.topSurfaceExpansionDirection(.outward).value == "outward")

    // Creality Print extension.
    #expect(SlicerSetting.supportBasePatternTree(.honeycomb).value == "honeycomb")
    #expect(SlicerSetting.overhangSpeedClassic(false).value == "0")
    #expect(SlicerSetting.overhangSpeedClassic(false).key == .overhangSpeedClassic)
}

@Test func onPlatterEmbedsModelSettingsConfigForComponentsWithSlicerSettings() async throws {
    // End-to-end: a component declared with slicerSettings must cause onPlatter() to embed a
    // Metadata/model_settings.config sidecar in the exported 3MF archive.
    let part = Part("Configured")
    let platter = Box(10)
        .asComponent(part, upDirection: .up, slicerSettings: [.sparseInfillDensity(15)])
        .onPlatter()

    let data = try await ModelFileGenerator.build { platter }.data()

    // The zip's central directory stores entry names as literal (uncompressed) bytes, so this is a
    // reliable way to confirm the file was actually added to the archive without needing a zip reader.
    #expect(data.range(of: Data("Metadata/model_settings.config".utf8)) != nil)
}

@Test func onPlatterOmitsModelSettingsConfigWithoutSlicerSettings() async throws {
    // No component declared slicerSettings, so no sidecar file should be added at all.
    let part = Part("Plain")
    let platter = Box(10)
        .asComponent(part, upDirection: .up)
        .onPlatter()

    let data = try await ModelFileGenerator.build { platter }.data()
    #expect(data.range(of: Data("Metadata/model_settings.config".utf8)) == nil)
}

@Test func asComponentEmbedsModelSettingsConfigWithoutOnPlatter() async throws {
    // slicerSettings must not require onPlatter() — a bare asComponent, exported directly, should
    // still embed the sidecar (asComponent's own part is never renamed/copied without packing, so it
    // resolves to a real object id on its own).
    let part = Part("Standalone")
    let component = Box(10).asComponent(part, upDirection: .up, slicerSettings: [.wallLoops(3)])

    let data = try await ModelFileGenerator.build { component }.data()
    #expect(data.range(of: Data("Metadata/model_settings.config".utf8)) != nil)
}

@Test func multipleComponentsWithoutOnPlatterShareOneModelSettingsConfigWithoutCrashing() async throws {
    // Every component with slicerSettings registers its own postprocessing handler independently.
    // With two components in the same export, both handlers run — this must not throw (a naive
    // "just always addFile" implementation would throw ZipError.duplicateFileEntry on the second one).
    let a = Part("A")
    let b = Part("B")
    let assembly = Box(10)
        .asComponent(a, upDirection: .up, slicerSettings: [.sparseInfillDensity(15)])
        .adding {
            Box(5)
                .asComponent(b, upDirection: .up, slicerSettings: [.sparseInfillDensity(80)])
        }

    let data = try await ModelFileGenerator.build { assembly }.data()
    #expect(data.range(of: Data("Metadata/model_settings.config".utf8)) != nil)
}
