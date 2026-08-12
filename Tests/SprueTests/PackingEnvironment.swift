import Foundation
import Testing
import Cadova
@testable import Sprue

struct PackingEnvironmentTests {
    @Test func `packing environment values default and round-trip`() {
        // Defaults when unset.
        #expect(EnvironmentValues().packingMargin == 1)
        #expect(EnvironmentValues().packingRotationCount == 4)

        // Round-trip through the EnvironmentValues setters.
        #expect(EnvironmentValues().withPackingMargin(2.5).packingMargin == 2.5)
        #expect(EnvironmentValues().withPackingRotationCount(8).packingRotationCount == 8)
    }
}
