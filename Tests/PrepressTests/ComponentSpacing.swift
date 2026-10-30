import Foundation
import Testing
import Cadova
@testable import Prepress

struct ComponentSpacingTests {
    @Test func `component spacing defaults and round-trips`() {
        // Default when unset.
        #expect(EnvironmentValues().componentSpacing == 2)

        // Round-trip through the EnvironmentValues setter.
        #expect(EnvironmentValues().withComponentSpacing(5).componentSpacing == 5)

        // The nester inflates each footprint by half the spacing, so two neighbors inflated that far
        // end up a full spacing apart rather than twice it.
        #expect(EnvironmentValues().footprintMargin == 1)
        #expect(EnvironmentValues().withComponentSpacing(5).footprintMargin == 2.5)
    }
}
