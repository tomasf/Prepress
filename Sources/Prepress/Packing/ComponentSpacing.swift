import Foundation
import Cadova

public extension EnvironmentValues {
    private static let spacingKey = Key("Packing.ComponentSpacing")

    /// The gap left between neighboring components when they're laid out on a platter, in millimeters.
    ///
    /// This is the distance between the parts themselves, which is what a print needs: enough room to
    /// get a scraper between them, and enough that their brims or elephant-foot bulges don't merge.
    /// Used by ``Cadova/Geometry3D/onPlatter(removingMaterials:separatingParts:)``. Defaults to 2.
    var componentSpacing: Double {
        get { self[Self.spacingKey] as? Double ?? 2 }
        set { self[Self.spacingKey] = newValue }
    }

    /// Returns a new environment with the component spacing set.
    func withComponentSpacing(_ spacing: Double) -> EnvironmentValues {
        setting(key: Self.spacingKey, value: spacing)
    }
}

public extension Geometry {
    /// Sets the gap left between neighboring components laid out beneath this point in the tree.
    ///
    /// - Parameter spacing: The gap between adjacent components, in millimeters.
    /// - Returns: The geometry with the component spacing applied to its environment.
    func withComponentSpacing(_ spacing: Double) -> D.Geometry {
        withEnvironment { $0.withComponentSpacing(spacing) }
    }
}

internal extension EnvironmentValues {
    /// How far each footprint is grown outward before nesting.
    ///
    /// The nester keeps footprints from overlapping, so two neighbors each inflated by this much end
    /// up a full ``componentSpacing`` apart. Half the spacing is therefore the right inflation.
    var footprintMargin: Double {
        componentSpacing / 2
    }
}
