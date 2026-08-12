import Foundation
import Testing
import Cadova
import Zip
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

// MARK: - Slicer settings

@Test func bambuConfigFormatsEntriesAndEscapesValues() throws {
    let part = Part("Widget")
    let entries = SlicerSettingsEntries([(part, .init(bambu: [
        .sparseInfillDensity: "15%",
        .wallLoops: "A & B <ok>",
    ]))])
    let data = try entries.bambuConfigData(objectID: { _ in 42 })
    let string = try #require(data).utf8String

    #expect(string.contains(#"<object id="42">"#))
    #expect(string.contains(#"key="sparse_infill_density" value="15%""#))
    // `>` isn't required to be escaped in XML attribute values, and Nodal (via pugixml) doesn't.
    #expect(string.contains(#"key="wall_loops" value="A &amp; B &lt;ok>""#))
    // Bambu's format has no `type` discriminator; that's PrusaSlicer's.
    #expect(!string.contains("type="))
}

@Test func configsSkipPartsWithUnresolvableObjectID() throws {
    // A part the caller can't resolve an id for (shouldn't happen for anything actually packed) is
    // skipped rather than emitting a malformed <object id="..."> entry.
    let entries = SlicerSettingsEntries([(Part("Orphan"), .init(bambu: [.wallLoops: "3"], prusa: [.perimeters: "3"]))])

    #expect(try entries.bambuConfigData(objectID: { _ in nil }) == nil)
    #expect(try entries.prusaConfigData(objectID: { _ in nil }, triangleCount: { _ in 12 }) == nil)
}

@Test func bambuConfigMergesMultipleEntriesResolvingToTheSameID() throws {
    // Regression: inComponent's own declaration and onPlatter's re-declaration against the final
    // packed part both resolve to the same id whenever packing didn't rename or copy the part (the
    // common quantity == 1, removingMaterials == false case) — this must produce one merged <object>
    // block, not two duplicate ones.
    let entries = SlicerSettingsEntries([
        (Part("A"), .init(bambu: [.wallLoops: "3"])),
        (Part("B"), .init(bambu: [.sparseInfillDensity: "20%"])), // distinct Part, same object id
    ])
    let data = try entries.bambuConfigData(objectID: { _ in 7 })
    let string = try #require(data).utf8String

    #expect(string.components(separatedBy: "<object").count == 2) // one split point == one <object> block
    #expect(string.contains(#"key="wall_loops" value="3""#))
    #expect(string.contains(#"key="sparse_infill_density" value="20%""#))
}

@Test func prusaConfigWritesAVolumeSpanningTheWholeMesh() throws {
    // The load-bearing rule of PrusaSlicer's format: once an <object> block exists, the block's
    // <volume> list *replaces* the default whole-mesh volume. An object written without one loads
    // with no geometry at all.
    let entries = SlicerSettingsEntries([(Part("Widget"), .init(prusa: [.fillDensity: "15%"]))])
    let data = try entries.prusaConfigData(objectID: { _ in 3 }, triangleCount: { _ in 12 })
    let string = try #require(data).utf8String

    #expect(string.contains(#"<object id="3">"#))
    #expect(string.contains(#"<metadata type="object" key="fill_density" value="15%" />"#))
    // Inclusive, 0-based triangle indices: 12 triangles spans 0...11.
    #expect(string.contains(#"<volume firstid="0" lastid="11">"#))
    #expect(string.components(separatedBy: "<volume").count == 2) // exactly one volume per object
}

@Test func prusaConfigSkipsObjectsWithoutAUsableTriangleCount() throws {
    // A wrong triangle range is worse than no settings: too high and PrusaSlicer refuses to open the
    // file at all, too low and it silently drops the triangles past the end. So an object whose count
    // couldn't be measured is left out entirely rather than guessed at.
    let entries = SlicerSettingsEntries([(Part("Widget"), .init(prusa: [.fillDensity: "15%"]))])

    #expect(try entries.prusaConfigData(objectID: { _ in 3 }, triangleCount: { _ in nil }) == nil)
    #expect(try entries.prusaConfigData(objectID: { _ in 3 }, triangleCount: { _ in 0 }) == nil)
}

@Test func infillPatternLowersToEachSlicersOwnVocabulary() {
    // Regression: Bambu Studio's raw config value for the pattern labeled "Rectilinear" in its UI is,
    // confusingly, "zig-zag" — and a *separate* raw value "zigzag" (no hyphen) exists for the actual
    // "Zig Zag" pattern. PrusaSlicer spells the first one plainly. Getting these crossed would
    // silently write the wrong pattern.
    #expect(SlicerSetting.infillPattern(.rectilinear).bambu == [.sparseInfillPattern: "zig-zag"])
    #expect(SlicerSetting.infillPattern(.rectilinear).prusa == [.fillPattern: "rectilinear"])
    #expect(SlicerSetting.infillPattern(.zigzag).bambu == [.sparseInfillPattern: "zigzag"])

    // PrusaSlicer pluralizes this one.
    #expect(SlicerSetting.infillPattern(.monotonicLine).bambu == [.sparseInfillPattern: "monotonicline"])
    #expect(SlicerSetting.infillPattern(.monotonicLine).prusa == [.fillPattern: "monotoniclines"])
}

@Test func patternsMissingFromASlicerAreOmittedRatherThanApproximated() {
    // A pattern only one slicer has must contribute *nothing* to the other's config. Substituting a
    // near-enough pattern would silently print something the caller didn't ask for; writing the
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

@Test func slicerSettingTypedFactoriesProduceExpectedRawValues() {
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
    #expect(SlicerSetting.supportBasePattern(.rectilinearGrid).bambu == [.supportBasePattern: "rectilinear-grid"])

    // The escape hatches are flavor-scoped, so a raw key can't land in the wrong file.
    #expect(SlicerSetting.raw(bambu: .enableSupport, "1").bambu == [.enableSupport: "1"])
    #expect(SlicerSetting.raw(bambu: .enableSupport, "1").prusa.isEmpty)
    #expect(SlicerSetting.raw(prusa: .supportMaterial, "1").prusa == [.supportMaterial: "1"])
    #expect(SlicerSetting.raw(prusa: .supportMaterial, "1").bambu.isEmpty)
}

@Test func settingsSplitAcrossSeveralOptionsInOneSlicer() {
    // Bambu folds the support algorithm and its automatic placement into one option; PrusaSlicer keeps
    // them apart, so one neutral setting has to lower to two keys there.
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

@Test func groupedSlicerSettingsOmitUnspecifiedParameters() {
    // The defining property of the grouped factories: a parameter left out writes *nothing*, so the
    // user's own slicer profile default survives. Writing a default of our own choosing here would
    // silently override settings they never asked us to touch.
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

@Test func groupedSupportImpliesEnableSupport() {
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

@Test func anglesAreWrittenAsDegreesWhicheverUnitTheyWereBuiltFrom() {
    // Both config formats want a bare number of degrees, so an angle expressed in any other unit has
    // to be converted rather than serialized as whatever it was constructed with.
    #expect(SlicerSetting.infillDirection(.radians(.pi / 4)).bambu == [.infillDirection: "45.0"])
    #expect(SlicerSetting.infillDirection(.radians(.pi / 4)).prusa == [.fillAngle: "45.0"])
    #expect(SlicerSetting.infillDirection(Angle(turns: 0.25)).prusa == [.fillAngle: "90.0"])

    // The support threshold is an integer option in both slicers, so it must not pick up a fractional
    // part from the Angle round-trip the way the double-valued angles do.
    #expect(SlicerSetting.supportThresholdAngle(40°).bambu == [.supportThresholdAngle: "40"])
    #expect(SlicerSetting.supportThresholdAngle(40°).prusa == [.supportMaterialThreshold: "40"])
    #expect(SlicerSetting.supportThresholdAngle(.radians(.pi / 4)).prusa == [.supportMaterialThreshold: "45"])
}

@Test func laterSlicerSettingsOverrideEarlierGroupedOnesPerKey() {
    // Groups and single-option factories mix in one array; collapsing is per key within each flavor,
    // last one wins, so a single setting can refine one value out of a group without discarding the
    // rest of it.
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

@Test func forkOnlySettingsNeverReachThePrusaConfig() {
    // OrcaSlicer/Creality extensions have no PrusaSlicer equivalent. Leaking one into that file would
    // make PrusaSlicer throw on the unknown key and refuse to open the whole 3MF.
    #expect(SlicerSetting.zContouringEnabled(true).bambu == [.zContouringEnabled: "1"])
    #expect(SlicerSetting.zContouringEnabled(true).prusa.isEmpty)

    #expect(SlicerSetting.topSurfaceExpansionDirection(.outward).prusa.isEmpty)
    #expect(SlicerSetting.supportBasePatternTree(.honeycomb).bambu == [.supportBasePatternTree: "honeycomb"])
    #expect(SlicerSetting.supportBasePatternTree(.honeycomb).prusa.isEmpty)
    #expect(SlicerSetting.overhangSpeedClassic(false).bambu == [.overhangSpeedClassic: "0"])
    #expect(SlicerSetting.overhangSpeedClassic(false).prusa.isEmpty)

    // Bambu renamed the anchor options in its forks, so both spellings go into that flavor's file —
    // each fork reads the one it knows. PrusaSlicer gets only its own.
    #expect(SlicerSetting.infillAnchor(50).bambu == [.sparseInfillAnchor: "50.0", .infillAnchor: "50.0"])
    #expect(SlicerSetting.infillAnchor(50).prusa == [.infillAnchor: "50.0"])
}

// MARK: - Slicer settings, end to end

private extension Data {
    var utf8String: String { String(decoding: self, as: UTF8.self) }
}

private extension String {
    /// The value of `name="…"` in this XML fragment, if present.
    func attributeValue(_ name: String) -> String? {
        guard let start = range(of: "\(name)=\"") else { return nil }
        let rest = self[start.upperBound...]
        guard let end = rest.firstIndex(of: "\"") else { return nil }
        return String(rest[..<end])
    }

    /// Every `<tag …>` fragment in this document, each running up to the next one.
    func fragments(forTag tag: String) -> [String] {
        Array(components(separatedBy: "<\(tag) ").dropFirst())
    }
}

private extension ZipArchive<Data> {
    func text(at path: String) throws -> String {
        try fileContents(at: path).utf8String
    }

    /// The number of triangles actually serialized for each build item, keyed by the same object id
    /// the config sidecars reference.
    func serializedTriangleCounts() throws -> [Int: Int] {
        var counts: [Int: Int] = [:]
        for item in try text(at: "3D/3dmodel.model").fragments(forTag: "item") {
            guard let id = item.attributeValue("objectid").flatMap(Int.init) else { continue }
            // Parts each get their own model file; a lone object stays inline in the root model.
            let path = item.attributeValue("p:path").map { String($0.dropFirst()) } ?? "3D/3dmodel.model"
            counts[id] = try text(at: path).fragments(forTag: "triangle").count
        }
        return counts
    }

    /// Each object id in PrusaSlicer's sidecar, paired with the `lastid` of its volume.
    func prusaVolumeRanges() throws -> [Int: (firstID: Int, lastID: Int)] {
        var ranges: [Int: (Int, Int)] = [:]
        for object in try text(at: SlicerSettingsEntries.prusaConfigPath).fragments(forTag: "object") {
            guard let id = object.attributeValue("id").flatMap(Int.init),
                  let volume = object.fragments(forTag: "volume").first,
                  let first = volume.attributeValue("firstid").flatMap(Int.init),
                  let last = volume.attributeValue("lastid").flatMap(Int.init)
            else { continue }
            ranges[id] = (first, last)
        }
        return ranges
    }
}

@Test func prusaVolumeRangeMatchesTheMeshActuallyWritten() async throws {
    // The one that matters most. PrusaSlicer validates this range against the serialized mesh and
    // fails the whole load when lastid runs past the end; a range that's merely short silently drops
    // triangles. Nothing else in the pipeline would catch an off-by-one or a mis-scoped measurement,
    // so this compares against the triangles genuinely present in the archive.
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

@Test func multipliedComponentsGetTheirOwnVolumeRanges() async throws {
    // A quantity above 1 makes packing emit each copy as its own renamed part, so the settings and
    // the volume range have to follow the *packed* part rather than the one the component declared.
    // Distinct shapes here so a mix-up between copies couldn't pass by coincidence.
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

@Test func nestedPartsAreExcludedFromTheVolumeRange() async throws {
    // Regression for the measurement scope. A part's geometry can still carry nested parts, which the
    // 3MF writer emits as their own objects rather than as part of this mesh — measuring with the
    // default `.solidParts` scope would count them twice over and overshoot the range, which
    // PrusaSlicer rejects outright.
    //
    // Deliberately *without* onPlatter(): packing strips nested parts out of a component, so routing
    // this through the platter would leave nothing nested to get the scope wrong about. The sphere is
    // far denser than the box, so a mis-scoped count overshoots by three orders of magnitude.
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

@Test func onPlatterEmbedsBothConfigSidecarsForComponentsWithSlicerSettings() async throws {
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

@Test func aSettingOnlyOneSlicerSupportsWritesOnlyThatSlicersFile() async throws {
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

@Test func onPlatterOmitsConfigsWithoutSlicerSettings() async throws {
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

@Test func inComponentEmbedsConfigsWithoutOnPlatter() async throws {
    // slicerSettings must not require onPlatter() — a bare inComponent, exported directly, should
    // still embed the sidecars (inComponent's own part is never renamed/copied without packing, so it
    // resolves to a real object id on its own).
    let component = Box(10).inComponent(Component("Standalone", upDirection: .up, slicerSettings: [.wallCount(3)]))

    let data = try await ModelFileGenerator.build { component }.data()
    let archive = try ZipArchive(data: data)

    #expect(archive.hasEntry(at: SlicerSettingsEntries.bambuConfigPath))
    #expect(archive.hasEntry(at: SlicerSettingsEntries.prusaConfigPath))
}

@Test func multipleComponentsShareOneConfigOfEachKindWithoutCrashing() async throws {
    // Every component with slicerSettings registers its own archive finalizer independently. With two
    // components in the same export, both run — this must not throw (a naive "just always addFile"
    // implementation would throw ZipError.duplicateFileEntry on the second one).
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
