import Foundation
import Testing
import Cadova
@testable import Sprue

struct ConvexPolygonTests {
    @Test func `convex hull removes collinear and duplicate points`() {
        // Duplicates and a midpoint on the bottom edge should collapse to the four corners.
        let poly = ConvexPolygon(hullOf: [[0, 0], [5, 0], [10, 0], [10, 10], [0, 10], [0, 10], [0, 0]])
        #expect(poly.vertices.count == 4)
        #expect(abs(poly.area - 100) < 1e-9)
    }

    @Test func `circumscribed polygon contains the original within its vertex budget`() {
        // A finely tessellated circle (the kind projected cylinders/spheres produce) must collapse to
        // a small vertex count while still fully containing the original.
        let original = ConvexPolygon.circle(radius: 20, pointCount: 360)
        let simplified = original.circumscribed(directionCount: 24)

        #expect(simplified.vertices.count <= 24)
        // Outer approximation: every original vertex stays inside (boundary tolerance).
        for v in original.vertices {
            #expect(simplified.strictlyContains(v) || simplified.containsOrTouches(v))
        }
    }

    @Test func `circumscribed thin footprint has no zero-length edges`() {
        // `circumscribed` simplifies a many-vertex hull by intersecting evenly spaced supporting
        // lines. For a long thin footprint, several adjacent supporting lines touch the same
        // near-flat edge and meet in near-coincident corners. Those must not survive as zero-length
        // edges: a zero-length edge makes `strictlyContains` reject every point and desyncs the
        // no-fit-polygon merge, so the nester places the piece overlapping its neighbours (the rc1
        // "Hub bearing house top" / tire overlap).
        let footprint = ConvexPolygon.thinFootprint().circumscribed(directionCount: 24)
        for i in footprint.vertices.indices {
            let a = footprint.vertices[i]
            let b = footprint.vertices[(i + 1) % footprint.vertices.count]
            #expect((a - b).magnitude > 1e-6, "zero-length edge between \(a) and \(b)")
        }
    }
}
