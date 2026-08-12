import Foundation
import Testing
import Cadova
@testable import Sprue

struct NestingTests {
    @Test func `nesting produces no overlaps`() {
        let polygons: [ConvexPolygon] = [
            ConvexPolygon(hullOf: [[0, 0], [40, 0], [40, 40], [0, 40]]),       // square
            ConvexPolygon(hullOf: [[0, 0], [60, 0], [60, 12], [0, 12]]),       // long rectangle
            ConvexPolygon(hullOf: [[0, 0], [30, 0], [15, 26]]),                // triangle
            ConvexPolygon(hullOf: [[0, 0], [20, 0], [20, 50], [0, 50]]),       // tall rectangle
            ConvexPolygon(hullOf: [[0, 0], [18, 0], [25, 18], [9, 28], [-3, 14]]), // pentagon
        ]

        let placements = nest(polygons, rotationCount: 4)
        #expect(placements.count == polygons.count)

        polygons.placed(with: placements).expectNoOverlaps()
    }

    @Test func `packed footprint is compact`() {
        // Eight identical squares should pack into a roughly square block, far tighter than laying
        // them out in a single row.
        let square = ConvexPolygon(hullOf: [[0, 0], [20, 0], [20, 20], [0, 20]])
        let polygons = Array(repeating: square, count: 8)

        let placed = polygons.placed(with: nest(polygons, rotationCount: 4))

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

        placed.expectNoOverlaps()
    }

    @Test func `nesting does not overlap a thin circumscribed footprint`() {
        // Regression for the rc1 Wheel platter: a thin part packed beside a large disc must not be
        // placed on top of it. The thin footprint's circumscribed corners used to collapse into
        // zero-length edges, breaking the nester's overlap test.
        let polygons = [
            ConvexPolygon.circle(radius: 60, pointCount: 64).circumscribed(directionCount: 24),
            ConvexPolygon.thinFootprint().circumscribed(directionCount: 24),
        ]

        polygons.placed(with: nest(polygons, rotationCount: 4)).expectNoOverlaps()
    }

    @Test func `nesting tolerates empty and degenerate footprints`() {
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
}
