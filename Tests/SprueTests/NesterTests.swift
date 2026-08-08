import Foundation
import Testing
import Cadova
@testable import Sprue

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

    let inner = ComponentData(.init(component: Component("Inner", quantity: 2), transform: .identity))
    let outer = ComponentData(.init(component: Component("Outer", upDirection: .down, quantity: 7), transform: .identity))
    #expect(ComponentData(combining: [inner, outer]).value?.component.quantity == 7)
    #expect(ComponentData(combining: [inner, ComponentData()]).value?.component.quantity == 2)
}

@Test func inComponentOverloadsCompile() {
    _ = Box(1)
        .inComponent(name: "Sideways", upDirection: .right)
    _ = Box(1)
        .inComponent(name: "Many", quantity: 3)
    _ = Box(1)
        .inComponent(Component("Custom", upDirection: .forward))
    _ = Box(1)
        .inComponent(Component("Repeated", quantity: 2))
    _ = Box(1)
        .inComponent(Component("Metallic", material: .init(baseColor: .red, metallicness: 1, roughness: 0.2)))

    // The same component marks several bodies, which merge into one part — the reason Component is a
    // value you can hold onto rather than something inComponent always creates internally.
    let shared = Component("Shared")
    _ = Box(1)
        .inComponent(shared)
        .adding {
            Box(2).translated(x: 5).inComponent(shared)
        }
}

@Test func eachComponentOwnsADistinctPart() {
    // Two components with the same name are still distinct parts, matching Cadova's Part semantics —
    // and since a Component builds its Part privately, two components can never share one and collapse
    // into a single object in the output.
    #expect(Component("Same").part != Component("Same").part)

    let reused = Component("Reused")
    #expect(reused.part == reused.part)
    #expect(reused.name == "Reused")

    // Quantity is clamped on the way in, so the packer never sees a nonsensical count.
    #expect(Component("None", quantity: 0).quantity == 1)
    #expect(Component("Negative", quantity: -3).quantity == 1)
}

@Test func platterOrientsComponentWithNestedPart() async throws {
    let main = Component("Main", upDirection: .right)
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

@Test func platterSkipsPartsThatArentComponents() async throws {
    // A plain part — even one with a Cadova natural up direction — is not a Sprue component, so the
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
    let outer = Component("Outer", upDirection: .up)
    let nested = Component("Nested", upDirection: .up)
    let capture = BoundsCapture()

    // A component nested inside another component is packed on its own, oriented by its own declared up
    // direction (like the rc1 hub-bearing-house-top inside the hub).
    let platter = Box(x: 10, y: 10, z: 10)
        .adding {
            Box(x: 8, y: 2, z: 5)
                .inComponent(nested)
        }
        .inComponent(outer)
        .rotated(x: 90°)
        .onPlatter(separatingParts: false)
        .withPackingRotationCount(1)
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

@Test func platterDoesNotMirrorPartAcrossDeclaredUpDirection() async throws {
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
        .withPackingRotationCount(1)
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
        .withPackingMargin(2)
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
    let xml = try SlicerSettingsEntries([(part, [.sparseInfillDensity: "15%", .wallLoops: "A & B <ok>"])])
        .configData(objectID: { _ in 42 })
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
    let xml = try SlicerSettingsEntries([(part, [.wallLoops: "3"])]).configData(objectID: { _ in nil })
    let string = String(decoding: xml, as: UTF8.self)

    #expect(!string.contains("<object"))
}

@Test func bambuModelSettingsConfigMergesMultipleEntriesResolvingToTheSameID() throws {
    // Regression: inComponent's own declaration and onPlatter's re-declaration against the final
    // packed part both resolve to the same id whenever packing didn't rename or copy the part (the
    // common quantity == 1, removingMaterials == false case) — this must produce one merged <object>
    // block, not two duplicate ones.
    let partA = Part("A")
    let partB = Part("B") // a distinct Part instance that still resolves to the same object id as A
    let xml = try SlicerSettingsEntries([(partA, [.wallLoops: "3"]), (partB, [.sparseInfillDensity: "20%"])])
        .configData(objectID: { _ in 7 })
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
    let xml = try SlicerSettingsEntries([(part, [.sparseInfillPattern: InfillPattern.rectilinear.rawValue])])
        .configData(objectID: { _ in 1 })
    let string = String(decoding: xml, as: UTF8.self)
    #expect(string.contains(#"key="sparse_infill_pattern" value="zig-zag""#))
}

@Test func slicerSettingTypedFactoriesProduceExpectedRawValues() {
    #expect(SlicerSetting.enableSupport(true).values == [.enableSupport: "1"])
    #expect(SlicerSetting.enableSupport(false).values == [.enableSupport: "0"])
    #expect(SlicerSetting.wallLoops(3).values == [.wallLoops: "3"])
    #expect(SlicerSetting.sparseInfillDensity(15).values == [.sparseInfillDensity: "15%"])
    #expect(SlicerSetting.layerHeight(0.2).values == [.layerHeight: "0.2"])
    #expect(SlicerSetting.seamPosition(.aligned).values == [.seamPosition: "aligned"])
    #expect(SlicerSetting.brimType(.outerOnly).values == [.brimType: "outer_only"])
    #expect(SlicerSetting.supportStyle(.treeOrganic).values == [.supportStyle: "tree_organic"])
    #expect(SlicerSetting.supportBasePattern(.rectilinearGrid).values == [.supportBasePattern: "rectilinear-grid"])
    #expect(SlicerSetting.wallSequence(.innerOuterInner).values == [.wallSequence: "inner-outer-inner wall"])
    #expect(SlicerSetting.ironingType(.noIroning).values == [.ironingType: "no ironing"])

    // All of these route through the same underlying key, whichever factory is used.
    #expect(SlicerSetting.raw(.enableSupport, "1").values == [.enableSupport: "1"])
}

@Test func groupedSlicerSettingsOmitUnspecifiedParameters() {
    // The defining property of the grouped factories: a parameter left out writes *nothing*, so the
    // user's own slicer profile default survives. Writing a default of our own choosing here would
    // silently override settings they never asked us to touch.
    #expect(SlicerSetting.sparseInfill(.gyroid).values == [.sparseInfillPattern: "gyroid"])

    #expect(SlicerSetting.sparseInfill(.gyroid, density: 20).values == [
        .sparseInfillPattern: "gyroid",
        .sparseInfillDensity: "20%",
    ])

    #expect(SlicerSetting.sparseInfill(.lightning, density: 10, anchor: 2.5, direction: 45).values == [
        .sparseInfillPattern: "lightning",
        .sparseInfillDensity: "10%",
        .sparseInfillAnchor: "2.5",
        .infillDirection: "45.0",
    ])

    // A group where every parameter is optional collapses to nothing at all rather than to defaults.
    #expect(SlicerSetting.flush().values.isEmpty)
}

@Test func groupedSupportImpliesEnableSupport() {
    // Regression: support_type without enable_support does nothing in Bambu Studio, so a part would
    // silently print unsupported. Naming a type has to imply the enable flag.
    #expect(SlicerSetting.support(.treeAuto).values == [
        .enableSupport: "1",
        .supportType: "tree(auto)",
    ])

    #expect(SlicerSetting.support(.normalAuto, style: .snug, thresholdAngle: 40, onBuildPlateOnly: true).values == [
        .enableSupport: "1",
        .supportType: "normal(auto)",
        .supportStyle: "snug",
        .supportThresholdAngle: "40",
        .supportOnBuildPlateOnly: "1",
    ])

    #expect(SlicerSetting.noSupport.values == [.enableSupport: "0"])
}

@Test func laterSlicerSettingsOverrideEarlierGroupedOnesPerKey() {
    // Groups and single-key factories mix in one array; collapsing is per key, last one wins, so a
    // single setting can refine one value out of a group without discarding the rest of it.
    let settings: [SlicerSetting] = [
        .sparseInfill(.gyroid, density: 20, anchor: 2),
        .sparseInfillDensity(50),
    ]

    #expect(settings.byKey == [
        .sparseInfillPattern: "gyroid",
        .sparseInfillDensity: "50%",
        .sparseInfillAnchor: "2.0",
    ])
}

@Test func forkExtensionFactoriesProduceExpectedRawValues() {
    // OrcaSlicer extension.
    #expect(SlicerSetting.zContouringEnabled(true).values == [.zContouringEnabled: "1"])
    #expect(SlicerSetting.infillAnchor(50).values == [.infillAnchor: "50.0"])
    #expect(SlicerSetting.topSurfaceExpansionDirection(.outward).values == [.topSurfaceExpansionDirection: "outward"])

    // Creality Print extension.
    #expect(SlicerSetting.supportBasePatternTree(.honeycomb).values == [.supportBasePatternTree: "honeycomb"])
    #expect(SlicerSetting.overhangSpeedClassic(false).values == [.overhangSpeedClassic: "0"])
}

@Test func onPlatterEmbedsModelSettingsConfigForComponentsWithSlicerSettings() async throws {
    // End-to-end: a component declared with slicerSettings must cause onPlatter() to embed a
    // Metadata/model_settings.config sidecar in the exported 3MF archive.
    let component = Component("Configured", upDirection: .up, slicerSettings: [.sparseInfillDensity(15)])
    let platter = Box(10)
        .inComponent(component)
        .onPlatter()

    let data = try await ModelFileGenerator.build { platter }.data()

    // The zip's central directory stores entry names as literal (uncompressed) bytes, so this is a
    // reliable way to confirm the file was actually added to the archive without needing a zip reader.
    #expect(data.range(of: Data("Metadata/model_settings.config".utf8)) != nil)
}

@Test func onPlatterOmitsModelSettingsConfigWithoutSlicerSettings() async throws {
    // No component declared slicerSettings, so no sidecar file should be added at all.
    let component = Component("Plain", upDirection: .up)
    let platter = Box(10)
        .inComponent(component)
        .onPlatter()

    let data = try await ModelFileGenerator.build { platter }.data()
    #expect(data.range(of: Data("Metadata/model_settings.config".utf8)) == nil)
}

@Test func inComponentEmbedsModelSettingsConfigWithoutOnPlatter() async throws {
    // slicerSettings must not require onPlatter() — a bare inComponent, exported directly, should
    // still embed the sidecar (inComponent's own part is never renamed/copied without packing, so it
    // resolves to a real object id on its own).
    let component = Box(10).inComponent(Component("Standalone", upDirection: .up, slicerSettings: [.wallLoops(3)]))

    let data = try await ModelFileGenerator.build { component }.data()
    #expect(data.range(of: Data("Metadata/model_settings.config".utf8)) != nil)
}

@Test func multipleComponentsWithoutOnPlatterShareOneModelSettingsConfigWithoutCrashing() async throws {
    // Every component with slicerSettings registers its own postprocessing handler independently.
    // With two components in the same export, both handlers run — this must not throw (a naive
    // "just always addFile" implementation would throw ZipError.duplicateFileEntry on the second one).
    let a = Component("A", upDirection: .up, slicerSettings: [.sparseInfillDensity(15)])
    let b = Component("B", upDirection: .up, slicerSettings: [.sparseInfillDensity(80)])
    let assembly = Box(10)
        .inComponent(a)
        .adding {
            Box(5)
                .inComponent(b)
        }

    let data = try await ModelFileGenerator.build { assembly }.data()
    #expect(data.range(of: Data("Metadata/model_settings.config".utf8)) != nil)
}
