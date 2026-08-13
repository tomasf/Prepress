import Foundation

/// The parts of a ``Component``'s configuration that only matter once it's laid out on a platter.
///
/// Everything here is inert until ``Cadova/Geometry3D/onPlatter(removingMaterials:)`` is called: a
/// component exported on its own is emitted once, whole, whatever these say. They're grouped for that
/// reason, and because the defaults suit the usual way of working.
///
/// The usual way being: build the model as it looks assembled, with each piece marked as a component
/// where it sits, then put the whole thing on a platter. Several bodies marked with the *same*
/// component merge into one part, so four wheels placed around an assembly arrive at the platter as
/// one part holding four disconnected solids — and ``separateSolids`` is what splits them back apart
/// to be laid out individually. ``quantity`` is for the other case, where the model contains one of
/// something but the print needs several.
public struct PlatterOptions: Sendable, Hashable {
    /// The number of copies to lay out. Always at least 1.
    public var quantity: Int {
        didSet { quantity = Swift.max(1, quantity) }
    }

    /// Whether the component's disconnected solids are laid out individually.
    ///
    /// Disconnected solids are separate physical objects, and packing them one by one nests tighter.
    /// Set this to `false` to keep them together as a rigid unit, for the cases where their relative
    /// arrangement is the point: a print-in-place hinge, a captive nut, a test piece whose spacing is
    /// being measured.
    public var separateSolids: Bool

    /// - Parameters:
    ///   - quantity: The number of copies to lay out. Values below 1 are treated as 1.
    ///   - separateSolids: Whether disconnected solids are laid out individually. Defaults to `true`.
    public init(quantity: Int = 1, separateSolids: Bool = true) {
        self.quantity = Swift.max(1, quantity)
        self.separateSolids = separateSolids
    }

    /// One copy, with disconnected solids laid out individually.
    public static let `default` = PlatterOptions()
}
