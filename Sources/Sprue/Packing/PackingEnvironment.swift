import Foundation
import Cadova

public extension EnvironmentValues {
    private static let marginKey = Key("Packing.Margin")
    private static let rotationCountKey = Key("Packing.RotationCount")

    /// How far each footprint is grown outward before packing, in millimeters.
    ///
    /// Neighboring pieces end up roughly `2 * packingMargin` apart. Used by both
    /// ``Swift/Array/packed(footprintDetail:)`` and ``Cadova/Geometry3D/onPlatter()``. Defaults to 1.
    var packingMargin: Double {
        get { self[Self.marginKey] as? Double ?? 1 }
        set { self[Self.marginKey] = newValue }
    }

    /// Returns a new environment with the packing margin set.
    func withPackingMargin(_ margin: Double) -> EnvironmentValues {
        setting(key: Self.marginKey, value: margin)
    }

    /// The number of evenly spaced rotations tried per piece when packing.
    ///
    /// Higher values pack tighter at the cost of more computation. Defaults to 4.
    var packingRotationCount: Int {
        get { self[Self.rotationCountKey] as? Int ?? 4 }
        set { self[Self.rotationCountKey] = newValue }
    }

    /// Returns a new environment with the packing rotation count set.
    func withPackingRotationCount(_ count: Int) -> EnvironmentValues {
        setting(key: Self.rotationCountKey, value: count)
    }
}

public extension Geometry {
    /// Sets the margin grown around each footprint when packing geometry beneath this point in the tree.
    ///
    /// - Parameter margin: The margin in millimeters. Neighboring pieces end up ~`2 * margin` apart.
    /// - Returns: The geometry with the packing margin applied to its environment.
    func withPackingMargin(_ margin: Double) -> D.Geometry {
        withEnvironment { $0.withPackingMargin(margin) }
    }

    /// Sets the number of rotations tried per piece when packing geometry beneath this point in the tree.
    ///
    /// - Parameter count: The number of evenly spaced rotations to try.
    /// - Returns: The geometry with the packing rotation count applied to its environment.
    func withPackingRotationCount(_ count: Int) -> D.Geometry {
        withEnvironment { $0.withPackingRotationCount(count) }
    }
}
