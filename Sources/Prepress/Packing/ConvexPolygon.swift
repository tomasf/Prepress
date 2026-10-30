import Foundation
import Cadova

/// A convex polygon with vertices stored in counter-clockwise order.
///
/// All footprints handled by the packer are convex (the convex hull of a projection, optionally
/// grown by a margin offset, stays convex), so a dedicated convex type lets the nester rely on cheap
/// convex-only algorithms (Minkowski-sum no-fit polygons, half-plane containment tests).
struct ConvexPolygon: Sendable, Hashable {
    /// Vertices in counter-clockwise winding order. Always at least three for a non-degenerate polygon.
    let vertices: [Vector2D]

    init(vertices: [Vector2D]) {
        self.vertices = vertices
    }

    /// Builds the convex hull of an arbitrary point cloud using Andrew's monotone chain algorithm.
    ///
    /// The outline points coming from Cadova are already convex and tessellated, but they may contain
    /// duplicates, collinear runs (from rounded offset joins) and an unspecified winding. The hull
    /// cleans all of that up into a minimal CCW vertex list.
    init(hullOf points: [Vector2D], epsilon: Double = 1e-6) {
        let sorted = points.sorted { $0.x != $1.x ? $0.x < $1.x : $0.y < $1.y }
        guard sorted.count >= 3 else {
            self.vertices = ConvexPolygon.droppingCoincidentVertices(sorted, epsilon: epsilon)
            return
        }

        func cross(_ o: Vector2D, _ a: Vector2D, _ b: Vector2D) -> Double {
            (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
        }

        var lower: [Vector2D] = []
        for p in sorted {
            while lower.count >= 2 && cross(lower[lower.count - 2], lower[lower.count - 1], p) <= 0 {
                lower.removeLast()
            }
            lower.append(p)
        }

        var upper: [Vector2D] = []
        for p in sorted.reversed() {
            while upper.count >= 2 && cross(upper[upper.count - 2], upper[upper.count - 1], p) <= 0 {
                upper.removeLast()
            }
            upper.append(p)
        }

        // Drop each list's last point because it's the first point of the other chain, then drop any
        // coincident vertices the chains left behind. Andrew's monotone chain can emit near-coincident
        // vertices at the chain junctions (the extreme points feeding both chains), and those zero-length
        // edges break the no-fit-polygon Minkowski-sum merge the nester relies on — producing a too-small
        // NFP and overlapping placements. Tessellated offset outlines from Cadova routinely produce such
        // coincident points.
        self.vertices = ConvexPolygon.droppingCoincidentVertices(Array(lower.dropLast()) + upper.dropLast(), epsilon: epsilon)
    }

    /// Removes vertices that coincide with their predecessor (cyclically) within `epsilon`, so the
    /// resulting ring has no zero-length edges.
    private static func droppingCoincidentVertices(_ vertices: [Vector2D], epsilon: Double) -> [Vector2D] {
        var result: [Vector2D] = []
        for v in vertices where result.last.map({ ($0 - v).magnitude > epsilon }) ?? true {
            result.append(v)
        }
        if result.count > 1, let first = result.first, let last = result.last, (first - last).magnitude <= epsilon {
            result.removeLast()
        }
        return result
    }
}

extension ConvexPolygon {
    /// The signed area; positive for the CCW winding produced by ``init(hullOf:)``.
    var area: Double {
        guard vertices.count >= 3 else { return 0 }
        var sum = 0.0
        for i in vertices.indices {
            let a = vertices[i]
            let b = vertices[(i + 1) % vertices.count]
            sum += a.x * b.y - b.x * a.y
        }
        return sum / 2
    }

    var boundingBox: (min: Vector2D, max: Vector2D) {
        guard let first = vertices.first else { return (.zero, .zero) }
        var lo = first, hi = first
        for v in vertices.dropFirst() {
            lo = Vector2D.min(lo, v)
            hi = Vector2D.max(hi, v)
        }
        return (lo, hi)
    }

    var size: Vector2D {
        let box = boundingBox
        return box.max - box.min
    }

    /// Rotates the polygon about the origin. Mirrors `Geometry3D.rotated(z:)`, which also rotates the
    /// body's footprint about the Z axis through the origin, so a rotation solved here can be replayed
    /// verbatim on the 3D body.
    func rotated(_ angle: Angle) -> ConvexPolygon {
        let c = cos(angle), s = sin(angle)
        return ConvexPolygon(vertices: vertices.map {
            Vector2D(x: $0.x * c - $0.y * s, y: $0.x * s + $0.y * c)
        })
    }

    func translated(by offset: Vector2D) -> ConvexPolygon {
        ConvexPolygon(vertices: vertices.map { $0 + offset })
    }

    func transformed(_ transform: Transform2D) -> ConvexPolygon {
        ConvexPolygon(vertices: vertices.map { transform.apply(to: $0) })
    }

    /// Negates every vertex (reflection through the origin), used to form the orbiting polygon of a
    /// no-fit polygon.
    var reflected: ConvexPolygon {
        ConvexPolygon(vertices: vertices.map { Vector2D(x: -$0.x, y: -$0.y) })
    }

    /// Returns whether `point` lies strictly inside the polygon (boundary counts as outside).
    ///
    /// Relies on the CCW winding: a point is interior when it sits strictly left of every edge.
    func strictlyContains(_ point: Vector2D, epsilon: Double = 1e-7) -> Bool {
        guard vertices.count >= 3 else { return false }
        for i in vertices.indices {
            let a = vertices[i]
            let b = vertices[(i + 1) % vertices.count]
            let cross = (b.x - a.x) * (point.y - a.y) - (b.y - a.y) * (point.x - a.x)
            if cross <= epsilon { return false }
        }
        return true
    }

    /// Returns a convex polygon with at most `directionCount` edges that fully **contains** this one.
    ///
    /// It is the intersection of `directionCount` supporting half-planes taken in evenly spaced
    /// directions (a circumscribed polygon). Because each half-plane is placed at the farthest extent
    /// of the original outline, every original point stays inside — so the simplified footprint is a
    /// conservative keep-out region and the packer can never produce an overlap by using it. This keeps
    /// the no-fit-polygon math fast: round offsets and projected circles otherwise carry hundreds of
    /// vertices.
    func circumscribed(directionCount: Int) -> ConvexPolygon {
        guard vertices.count > directionCount, directionCount >= 3 else { return self }

        // For each direction, the supporting line is `normal · x = maxProjection`.
        let lines: [(normal: Vector2D, offset: Double)] = (0 ..< directionCount).map { k in
            let angle = Angle(turns: Double(k) / Double(directionCount))
            let normal = Vector2D(x: cos(angle), y: sin(angle))
            let offset = vertices.map { $0.x * normal.x + $0.y * normal.y }.max()!
            return (normal, offset)
        }

        var corners: [Vector2D] = []
        for k in lines.indices {
            let a = lines[k], b = lines[(k + 1) % lines.count]
            let det = a.normal.x * b.normal.y - a.normal.y * b.normal.x
            if Swift.abs(det) < 1e-12 { continue }
            corners.append(Vector2D(
                x: (a.offset * b.normal.y - b.offset * a.normal.y) / det,
                y: (a.normal.x * b.offset - b.normal.x * a.offset) / det
            ))
        }
        return ConvexPolygon(hullOf: corners)
    }

    /// The rotation that, when applied, aligns the polygon's minimum-area bounding rectangle with the
    /// axes. Computed with rotating calipers: the optimal rectangle always shares an edge with the
    /// hull, so it suffices to test the angle of each edge.
    var minimumAreaRectangleAngle: Angle {
        guard vertices.count >= 3 else { return 0° }
        var best = (area: Double.greatestFiniteMagnitude, angle: 0°)
        for i in vertices.indices {
            let a = vertices[i]
            let b = vertices[(i + 1) % vertices.count]
            let edgeAngle = atan2(b - a)
            let boxSize = rotated(-edgeAngle).size
            let boxArea = boxSize.x * boxSize.y
            if boxArea < best.area {
                best = (boxArea, -edgeAngle)
            }
        }
        return best.angle
    }
}
