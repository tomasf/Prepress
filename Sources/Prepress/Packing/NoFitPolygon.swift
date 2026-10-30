import Foundation
import Cadova

/// Computes the no-fit polygon (NFP) for a pair of convex polygons.
///
/// The NFP describes, for an `orbiting` polygon sliding around a `stationary` one, the locus of the
/// orbiting polygon's reference point (its local origin). If the reference point is placed:
///   - strictly **inside** the NFP, the two polygons overlap,
///   - **on** the NFP boundary, they touch without overlapping,
///   - **outside** the NFP, they are separated.
///
/// For two convex polygons the NFP is itself convex and equals the Minkowski sum of `stationary` and
/// the point-reflected `orbiting`, which can be assembled in linear time by merging the two edge lists
/// in angular order.
func noFitPolygon(stationary: ConvexPolygon, orbiting: ConvexPolygon) -> ConvexPolygon {
    minkowskiSum(stationary, orbiting.reflected)
}

/// Convex Minkowski sum via angular edge merge. Both inputs must be convex with CCW winding.
private func minkowskiSum(_ a: ConvexPolygon, _ b: ConvexPolygon) -> ConvexPolygon {
    let p = reorderedFromBottom(a.vertices)
    let q = reorderedFromBottom(b.vertices)
    guard p.count >= 3, q.count >= 3 else {
        // Degenerate input — fall back to the hull of all pairwise sums.
        return ConvexPolygon(hullOf: p.flatMap { pa in q.map { pa + $0 } })
    }

    let n = p.count, m = q.count
    // Repeat the first two vertices so `P[i + 1]` stays valid as the indices wrap past the end.
    let pp = p + [p[0], p[1]]
    let qq = q + [q[0], q[1]]

    var result: [Vector2D] = []
    result.reserveCapacity(n + m)
    var i = 0, j = 0
    while i < n || j < m {
        result.append(pp[i] + qq[j])
        let edgeP = pp[i + 1] - pp[i]
        let edgeQ = qq[j + 1] - qq[j]
        let cross = edgeP.x * edgeQ.y - edgeP.y * edgeQ.x
        if cross >= 0 && i < n { i += 1 }
        if cross <= 0 && j < m { j += 1 }
    }
    return ConvexPolygon(vertices: result)
}

/// Rotates a CCW vertex list so it begins at the bottom-most (then left-most) vertex, which makes the
/// edge angles monotonically increasing — the precondition for the merge above.
private func reorderedFromBottom(_ vertices: [Vector2D]) -> [Vector2D] {
    guard let start = vertices.indices.min(by: { lhs, rhs in
        let a = vertices[lhs], b = vertices[rhs]
        return a.y != b.y ? a.y < b.y : a.x < b.x
    }) else { return vertices }
    return Array(vertices[start...] + vertices[..<start])
}
