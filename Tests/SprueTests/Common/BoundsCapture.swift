import Foundation
import Cadova

/// Carries measurements out of an `evaluating` closure, which runs during the build rather than at
/// the point of assertion.
final class BoundsCapture: @unchecked Sendable {
    var bounds: BoundingBox3D?
    var bottomSurfaceHitCount: Int?
    var topSurfaceHitCount: Int?
    var partsOverlap: Bool?
    var partWasPacked: Bool?
    var partNames: Set<String>?
}
