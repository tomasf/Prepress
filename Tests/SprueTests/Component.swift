import Foundation
import Testing
import Cadova
@testable import Sprue

struct ComponentTests {
    @Test func `component data combines last-wins`() {
        // Defaults to "not a component"; combining is last-wins so an outermost declaration takes
        // precedence, and a nil (plain part) never clobbers a real value.
        #expect(ComponentData().value == nil)

        let inner = ComponentData(.init(
            component: Component("Inner", platter: .init(quantity: 2)), upDirection: .up, transform: .identity
        ))
        let outer = ComponentData(.init(
            component: Component("Outer", platter: .init(quantity: 7)), upDirection: .down, transform: .identity
        ))
        #expect(ComponentData(combining: [inner, outer]).value?.component.platter.quantity == 7)
        #expect(ComponentData(combining: [inner, ComponentData()]).value?.component.platter.quantity == 2)
    }

    @Test func `inComponent overloads compile`() {
        _ = Box(1)
            .inComponent(name: "Sideways", upDirection: .right)
        _ = Box(1)
            .inComponent(name: "Many", platter: .init(quantity: 3))
        _ = Box(1)
            .inComponent(Component("Custom"), upDirection: .forward)
        _ = Box(1)
            .inComponent(Component("Repeated", platter: .init(quantity: 2)))
        _ = Box(1)
            .inComponent(Component("Metallic", material: .init(baseColor: .red, metallicness: 1, roughness: 0.2)))

        // The same component marks several bodies, which merge into one part — the reason Component
        // is a value you can hold onto rather than something inComponent always creates internally.
        let shared = Component("Shared")
        _ = Box(1)
            .inComponent(shared)
            .adding {
                Box(2).translated(x: 5).inComponent(shared)
            }
    }

    @Test func `each component has a distinct identity`() {
        // Two components with the same name are still distinct identities, so they can never collapse
        // into a single object in the output.
        #expect(Component("Same").id != Component("Same").id)

        let reused = Component("Reused")
        #expect(reused.id == reused.id)
        #expect(reused.name == "Reused")

        // Quantity is clamped on the way in, so the packer never sees a nonsensical count.
        #expect(Component("None", platter: .init(quantity: 0)).platter.quantity == 1)
        #expect(Component("Negative", platter: .init(quantity: -3)).platter.quantity == 1)
        #expect(PlatterOptions.default.quantity == 1)
        #expect(PlatterOptions.default.separateSolids)
    }
}
