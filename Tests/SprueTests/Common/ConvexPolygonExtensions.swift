import Foundation
import Testing
import Cadova
@testable import Sprue

extension ConvexPolygon {
    /// Independent separating-axis overlap test, kept separate from the nester's own no-fit-polygon
    /// math so the tests don't merely re-assert the production code. True only when the two polygons
    /// share positive area; merely touching edges or vertices is not an overlap.
    func overlaps(_ other: ConvexPolygon, epsilon: Double = 1e-6) -> Bool {
        for axis in edgeNormals + other.edgeNormals {
            let ourProjections = vertices.map { $0 ⋅ axis }
            let theirProjections = other.vertices.map { $0 ⋅ axis }
            let ourMin = ourProjections.min()!, ourMax = ourProjections.max()!
            let theirMin = theirProjections.min()!, theirMax = theirProjections.max()!
            // A gap on any axis (allowing a touching tolerance) means no overlap.
            if ourMax <= theirMin + epsilon || theirMax <= ourMin + epsilon {
                return false
            }
        }
        return true
    }

    /// Whether a point lies inside this polygon or on its boundary, within a tolerance.
    func containsOrTouches(_ point: Vector2D, epsilon: Double = 1e-6) -> Bool {
        for i in vertices.indices {
            let a = vertices[i]
            let b = vertices[(i + 1) % vertices.count]
            let cross = (b.x - a.x) * (point.y - a.y) - (b.y - a.y) * (point.x - a.x)
            if cross < -epsilon { return false }
        }
        return true
    }

    private var edgeNormals: [Vector2D] {
        vertices.indices.map { i in
            let p = vertices[i]
            let q = vertices[(i + 1) % vertices.count]
            let edge = q - p
            return Vector2D(x: -edge.y, y: edge.x)
        }
    }
}

extension ConvexPolygon {
    /// A finely tessellated circle, the kind projected cylinders and spheres produce.
    static func circle(radius: Double, pointCount: Int) -> ConvexPolygon {
        ConvexPolygon(hullOf: (0 ..< pointCount).map { i in
            let a = Angle(turns: Double(i) / Double(pointCount))
            return Vector2D(x: radius * cos(a), y: radius * sin(a))
        })
    }

    /// A finely tessellated, high-aspect-ratio outline — the shape of a long thin part like the rc1
    /// "Hub bearing house top". Circumscribing it is where coincident corners arise.
    static func thinFootprint(halfWidth: Double = 30, halfHeight: Double = 2, pointCount: Int = 120) -> ConvexPolygon {
        ConvexPolygon(hullOf: (0 ..< pointCount).map { i in
            let a = Angle(turns: Double(i) / Double(pointCount))
            return Vector2D(x: halfWidth * cos(a), y: halfHeight * sin(a))
        })
    }
}

extension Array where Element == ConvexPolygon {
    /// Places each polygon with the matching transform, in order.
    func placed(with transforms: [Transform2D]) -> [ConvexPolygon] {
        zip(self, transforms).map { $0.transformed($1) }
    }

    /// Expects that no two polygons share positive area, naming the offending pair when they do.
    func expectNoOverlaps(sourceLocation: SourceLocation = #_sourceLocation) {
        for i in indices {
            for j in (i + 1) ..< count {
                #expect(!self[i].overlaps(self[j]), "pieces \(i) and \(j) overlap", sourceLocation: sourceLocation)
            }
        }
    }
}
