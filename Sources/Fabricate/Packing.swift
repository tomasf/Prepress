import Foundation
import Cadova

public extension Array where Element == any Geometry3D {
    /// Packs these 3D bodies onto a single platter for 3D printing, minimizing the overall footprint.
    ///
    /// Each body is projected straight down onto the XY plane, reduced to its convex hull, and grown by
    /// the environment's ``Cadova/EnvironmentValues/packingMargin`` to form a keep-out footprint. Those
    /// footprints are then nested together with a no-fit polygon algorithm (see
    /// ``nest(_:rotationCount:includeMinAreaAngle:)``) that searches over 2D rotations and translations
    /// for the tightest arrangement. Finally each original body is returned rotated about the Z axis and
    /// translated in XY by the same transform its footprint received, so the solids end up arranged
    /// exactly like their packed footprints.
    ///
    /// The margin and the number of rotations tried come from the environment
    /// (``Cadova/EnvironmentValues/packingMargin`` and ``Cadova/EnvironmentValues/packingRotationCount``);
    /// set them with ``Cadova/Geometry/withPackingMargin(_:)`` and
    /// ``Cadova/Geometry/withPackingRotationCount(_:)``.
    ///
    /// - Parameter footprintDetail: The maximum number of edges each footprint is simplified to before
    ///   nesting. Footprints are simplified outward (so they only ever grow), which keeps the
    ///   no-fit-polygon math fast without risking overlaps. Defaults to 24.
    /// - Returns: The bodies, repositioned into a packed platter.
    func packed(footprintDetail: Int = 24) -> any Geometry3D {
        let bodies = self
        return Empty<D3>().evaluating { _, evaluator in
            @Environment(\.packingMargin) var margin
            @Environment(\.packingRotationCount) var rotationCount
            let packer = Packer(bodies: bodies, margin: margin, rotationCount: rotationCount, footprintDetail: footprintDetail)
            let placements = await packer.placements(using: evaluator)
            packer.place(with: placements)
        }
    }
}

/// Drives the packing pipeline. A single `evaluating` block reads every body's footprint through one
/// ``GeometryEvaluator`` — sharing one cache and one context — so the footprints can be gathered in a
/// plain loop before the nester runs and the placed bodies are emitted.
struct Packer: Sendable {
    let bodies: [any Geometry3D]
    let margin: Double
    let rotationCount: Int
    let footprintDetail: Int

    /// Reads each body's keep-out footprint and solves the packing arrangement.
    func placements(using evaluator: GeometryEvaluator) async -> [Transform2D] {
        var footprints: [ConvexPolygon] = []
        for body in bodies {
            let outline = body.projected().convexHull().offset(amount: margin, style: .miter)
            let points = await evaluator.outlines(of: outline).flatMap { $0.points(segmentation: .fixed(1)) }
            footprints.append(ConvexPolygon(hullOf: points).circumscribed(directionCount: footprintDetail))
        }
        return nest(footprints, rotationCount: rotationCount)
    }

    /// Places each body using its solved transform, lifting the 2D placement into 3D so it rotates the
    /// body about the Z axis and translates it in XY.
    @GeometryBuilder3D
    func place(with placements: [Transform2D]) -> any Geometry3D {
        for (body, placement) in zip(bodies, placements) {
            body.transformed(placement.transform3D)
        }
    }
}
