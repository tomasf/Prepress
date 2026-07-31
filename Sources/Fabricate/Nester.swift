import Foundation
import Cadova

/// Packs convex footprints into the smallest combined footprint using no-fit-polygon nesting.
///
/// The strategy is a bottom-left-fill (BLF) nester driven by no-fit polygons:
///   1. Pieces are placed largest first into an open-topped strip of a fixed width.
///   2. For each piece, several candidate rotations are tried.
///   3. Candidate reference positions come from the no-fit polygons against every already-placed
///      piece: their vertices (touching one piece), the intersections between two NFPs (touching two
///      pieces), and the intersections of NFP edges with the strip walls and floor. This is the
///      standard NFP candidate set and is what lets a piece nestle flush against neighbors and walls.
///   4. Among all feasible (non-overlapping, in-bounds) candidates, the lowest — then left-most — is
///      chosen.
/// Several strip widths are tried and the arrangement with the smallest overall bounding box wins, so
/// the result approximates the smallest footprint without a fixed bed size.
///
/// - Parameters:
///   - polygons: The footprints, in their original XY frame (matching each body's projection).
///   - rotationCount: How many evenly spaced rotations to try per piece (>= 1).
///   - includeMinAreaAngle: Also try each piece's minimum-area-rectangle orientation.
/// - Returns: One placement transform per input polygon, in the original input order. Each transform
///   rotates the footprint about the origin and translates it into place; applying it (or its 3D
///   equivalent) reproduces the packed position.
func nest(_ polygons: [ConvexPolygon], rotationCount: Int = 4, includeMinAreaAngle: Bool = true) -> [Transform2D] {
    guard !polygons.isEmpty else { return [] }

    func candidateAngles(for polygon: ConvexPolygon) -> [Angle] {
        var angles = (0 ..< max(1, rotationCount)).map { Angle(turns: Double($0) / Double(max(1, rotationCount))) }
        if includeMinAreaAngle {
            angles.append(polygon.minimumAreaRectangleAngle)
        }
        return angles
    }

    // Largest pieces first — they are hardest to place and define the overall shape.
    let order = polygons.indices.sorted { polygons[$0].area > polygons[$1].area }
    let rotationsByIndex = polygons.map { candidateAngles(for: $0) }

    let totalArea = polygons.reduce(0.0) { $0 + $1.area }
    // The strip must be at least as wide as the narrowest orientation of every piece.
    let minWidth = polygons.indices.map { index in
        rotationsByIndex[index].map { polygons[index].rotated($0).size.x }.min() ?? 0
    }.max() ?? 0
    let base = max(totalArea.squareRoot(), minWidth)
    // Sweep a range of strip widths around the square-area side length. The widths near 1.0–1.6× the
    // square side tend to come out roughly square once packing inefficiency stretches the strip taller
    // than wide, so a fairly fine sweep gives the squareness objective good arrangements to choose from.
    let widths = [0.7, 0.85, 1.0, 1.15, 1.3, 1.5, 1.7, 2.0, 2.4].map { max($0 * base, minWidth) }

    // Pick the arrangement that fits the smallest square: 3D-printer beds are roughly square, so the
    // binding constraint is the layout's longer side, not its area. Minimizing the longer side keeps the
    // result square-ish; ties (and near-ties) are broken by total bounding-box area so we still pack
    // tightly. Without this the packer minimized area alone and happily produced long thin strips.
    var best: (longerSide: Double, area: Double, placements: [Transform2D])? = nil
    for width in widths {
        let placements = pack(order: order, width: width, polygons: polygons, rotationsByIndex: rotationsByIndex)
        let size = boundingSize(of: placements, polygons: polygons)
        let longerSide = Swift.max(size.x, size.y)
        let area = size.x * size.y
        if let current = best {
            // Treat near-equal longer sides (within 1%) as ties and prefer the tighter area.
            let tolerance = current.longerSide * 0.01
            let better = longerSide < current.longerSide - tolerance
                || (longerSide <= current.longerSide + tolerance && area < current.area)
            if better { best = (longerSide, area, placements) }
        } else {
            best = (longerSide, area, placements)
        }
    }
    return best!.placements
}

/// Composes the placement transform: rotate the footprint about the origin, then translate it.
private func placementTransform(angle: Angle, translation: Vector2D) -> Transform2D {
    .rotation(angle).concatenated(with: .translation(translation))
}

/// Packs all pieces into a strip of the given width with bottom-left-fill placement.
private func pack(
    order: [Int],
    width: Double,
    polygons: [ConvexPolygon],
    rotationsByIndex: [[Angle]]
) -> [Transform2D] {
    var placements = [Transform2D?](repeating: nil, count: polygons.count)
    var placed: [ConvexPolygon] = []

    for index in order {
        var bestForPiece: (key: (Double, Double), transform: Transform2D, placed: ConvexPolygon)? = nil

        for angle in rotationsByIndex[index] {
            let rotated = polygons[index].rotated(angle)
            let box = rotated.boundingBox
            let floor = -box.min.y
            let xLow = -box.min.x
            let xHigh = width - box.max.x
            if xHigh < xLow - 1e-6 { continue } // wider than the strip in this orientation

            let nfps = placed.map { noFitPolygon(stationary: $0, orbiting: rotated) }
            for translation in candidatePositions(nfps: nfps, xLow: xLow, xHigh: xHigh, floor: floor) {
                if nfps.contains(where: { $0.strictlyContains(translation) }) { continue }

                // Bottom-left objective: lowest piece top, then left-most.
                let key = (translation.y + box.max.y, translation.x)
                if bestForPiece == nil || key < bestForPiece!.key {
                    bestForPiece = (key, placementTransform(angle: angle, translation: translation), rotated.translated(by: translation))
                }
            }
        }

        let chosen = bestForPiece ?? fallbackPlacement(index: index, placed: placed, polygons: polygons, rotationsByIndex: rotationsByIndex)
        placements[index] = chosen.transform
        placed.append(chosen.placed)
    }

    return placements.map { $0! }
}

/// Builds the standard NFP candidate-position set, clamped to the strip's feasible reference region
/// (`x` in `[xLow, xHigh]`, `y >= floor`).
private func candidatePositions(nfps: [ConvexPolygon], xLow: Double, xHigh: Double, floor: Double) -> [Vector2D] {
    var candidates: [Vector2D] = [Vector2D(x: xLow, y: floor), Vector2D(x: xHigh, y: floor)]
    if nfps.isEmpty { return candidates }

    let wallLines: [Line] = [.vertical(xLow), .vertical(xHigh), .horizontal(floor)]

    for (i, nfp) in nfps.enumerated() {
        candidates.append(contentsOf: nfp.vertices)
        for edge in nfp.edges {
            // Contacts with the strip walls and floor.
            for line in wallLines {
                if let p = edge.intersection(with: line) { candidates.append(p) }
            }
            // Contacts that touch two placed pieces at once.
            for other in nfps[(i + 1)...] {
                for otherEdge in other.edges {
                    if let p = edge.intersection(with: otherEdge) { candidates.append(p) }
                }
            }
        }
    }

    return candidates.filter { $0.x >= xLow - 1e-6 && $0.x <= xHigh + 1e-6 && $0.y >= floor - 1e-6 }
}

/// Defensive fallback (convex NFPs always expose feasible candidates, so this is unreachable in
/// practice): drop the piece on the floor clear to the right of everything placed.
private func fallbackPlacement(
    index: Int,
    placed: [ConvexPolygon],
    polygons: [ConvexPolygon],
    rotationsByIndex: [[Angle]]
) -> (key: (Double, Double), transform: Transform2D, placed: ConvexPolygon) {
    let angle = rotationsByIndex[index].first ?? 0°
    let rotated = polygons[index].rotated(angle)
    let rightEdge = placed.map { $0.boundingBox.max.x }.max() ?? 0
    let translation = Vector2D(x: rightEdge - rotated.boundingBox.min.x, y: -rotated.boundingBox.min.y)
    return ((0, 0), placementTransform(angle: angle, translation: translation), rotated.translated(by: translation))
}

private func boundingSize(of placements: [Transform2D], polygons: [ConvexPolygon]) -> Vector2D {
    let placed = zip(polygons, placements).map { $0.transformed($1) }
    guard let first = placed.first else { return .zero }
    var lo = first.boundingBox.min, hi = first.boundingBox.max
    for poly in placed.dropFirst() {
        lo = Vector2D.min(lo, poly.boundingBox.min)
        hi = Vector2D.max(hi, poly.boundingBox.max)
    }
    return hi - lo
}

// MARK: - Geometry helpers

/// A line used for wall/floor contacts and edge intersections.
private enum Line {
    case vertical(Double)    // x = value
    case horizontal(Double)  // y = value
    case segment(Vector2D, Vector2D)
}

private extension ConvexPolygon {
    var edges: [Line] {
        vertices.indices.map { .segment(vertices[$0], vertices[($0 + 1) % vertices.count]) }
    }
}

private extension Line {
    /// Intersection of two finite segments, or of a segment with an infinite wall/floor line. Returns
    /// `nil` unless `self` is a segment (the candidate-generation caller only ever asks segment-first).
    func intersection(with other: Line) -> Vector2D? {
        guard case let .segment(a, b) = self else { return nil }
        switch other {
        case let .vertical(x):
            return intersect(a, b, crossingX: x)
        case let .horizontal(y):
            return intersect(a, b, crossingY: y)
        case let .segment(c, d):
            return intersectSegments(a, b, c, d)
        }
    }
}

private func intersect(_ a: Vector2D, _ b: Vector2D, crossingX x: Double) -> Vector2D? {
    let dx: Double = b.x - a.x
    if Swift.abs(dx) < 1e-12 { return nil }
    let t: Double = (x - a.x) / dx
    guard t >= -1e-9, t <= 1 + 1e-9 else { return nil }
    return Vector2D(x: x, y: a.y + t * (b.y - a.y))
}

private func intersect(_ a: Vector2D, _ b: Vector2D, crossingY y: Double) -> Vector2D? {
    let dy: Double = b.y - a.y
    if Swift.abs(dy) < 1e-12 { return nil }
    let t: Double = (y - a.y) / dy
    guard t >= -1e-9, t <= 1 + 1e-9 else { return nil }
    return Vector2D(x: a.x + t * (b.x - a.x), y: y)
}

private func intersectSegments(_ a: Vector2D, _ b: Vector2D, _ c: Vector2D, _ d: Vector2D) -> Vector2D? {
    let r: Vector2D = b - a, s: Vector2D = d - c
    let denom: Double = r.x * s.y - r.y * s.x
    if Swift.abs(denom) < 1e-12 { return nil }
    let t: Double = ((c.x - a.x) * s.y - (c.y - a.y) * s.x) / denom
    let u: Double = ((c.x - a.x) * r.y - (c.y - a.y) * r.x) / denom
    guard t >= -1e-9, t <= 1 + 1e-9, u >= -1e-9, u <= 1 + 1e-9 else { return nil }
    return a + r * t
}
