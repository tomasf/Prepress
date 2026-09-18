import Foundation
import Cadova

/// Where each laid-out piece belongs in the assembled model.
///
/// ``Cadova/Geometry3D/onPlatter(removingMaterials:)`` flattens an assembly onto the bed. This
/// remembers the arrangement it started from, which is otherwise thrown away: the exported file would
/// be a plate of loose parts with nothing recording how they fit together.
///
/// Sprue is the only thing in the pipeline that knows this. A slicer opening the file sees parts side
/// by side on a bed; the model knows where each one came from.
struct AssemblyPlacements: ResultElement {
    /// Per part, the transform taking its mesh from where it sits on the plate back to where it sat in
    /// the assembly.
    var posesByPart: [Part: Transform3D]

    init() { posesByPart = [:] }
    init(_ posesByPart: [Part: Transform3D]) { self.posesByPart = posesByPart }
    init(combining elements: [AssemblyPlacements]) {
        // Each part is placed exactly once, so there's nothing to reconcile; a first-wins merge just
        // gathers them.
        posesByPart = elements.reduce(into: [:]) { result, element in
            result.merge(element.posesByPart) { current, _ in current }
        }
    }
}

internal extension Transform3D {
    /// The 3×4 affine part written column by column, which is the layout Bambu Studio's `transform`
    /// attribute uses (`bbs_3mf.cpp`, `_BBS_3MF_Exporter`: `for c { for r { m(r, c) } }`).
    var assembleAttributeValue: String {
        (0 ..< 4)
            .flatMap { column in (0 ..< 3).map { row in self[row, column] } }
            .map { String($0) }
            .joined(separator: " ")
    }
}

/// Which parts a component's pieces were grouped into, per emitted host.
///
/// A part declared inside a component travels with it, and the two have to reach the slicer as one
/// object made of several volumes. Anything else falls apart on import: a slicer drops each object it
/// loads onto the bed, so a passenger emitted as an object of its own lands at z = 0 instead of inside
/// its host (`Model.cpp`, `ModelObject::ensure_on_bed` — an object with one volume and nothing below
/// the bed is pushed down onto it, while one with several volumes is left alone).
///
/// The grouping is recorded here and applied when the archive is finalized, by rewriting the model
/// file: each host becomes an object whose content is components referencing its own mesh and its
/// passengers'.
struct PartGrouping: ResultElement {
    /// Per host part, the passengers riding with it, in the order they should appear.
    var passengersByHost: [Part: [Part]]

    init() { passengersByHost = [:] }
    init(passengersByHost: [Part: [Part]]) { self.passengersByHost = passengersByHost }
    init(combining elements: [PartGrouping]) {
        passengersByHost = elements.reduce(into: [:]) { result, element in
            result.merge(element.passengersByHost) { current, _ in current }
        }
    }

    /// Every part that rides inside another, so it isn't also treated as an object in its own right.
    var passengers: Set<Part> {
        Set(passengersByHost.values.flatMap { $0 })
    }
}
