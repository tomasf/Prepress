import Foundation
import Testing
import Cadova
@testable import Sprue

struct SlicerConfigWriterTests {
    @Test func `bambu config formats entries and escapes values`() throws {
        let part = Part("Widget")
        let entries = SlicerSettingsEntries([(part, .init(bambu: [
            .sparseInfillDensity: "15%",
            .wallLoops: "A & B <ok>",
        ]))])
        let data = try entries.bambuConfigData(objectID: { _ in 42 }, objectName: { _ in "Widget" })
        let string = try #require(data).utf8String

        #expect(string.contains(#"<object id="42">"#))
        #expect(string.contains(#"key="sparse_infill_density" value="15%""#))
        // `>` isn't required to be escaped in XML attribute values, and Nodal (via pugixml) doesn't.
        #expect(string.contains(#"key="wall_loops" value="A &amp; B &lt;ok>""#))
        // Bambu's format has no `type` discriminator; that's PrusaSlicer's.
        #expect(!string.contains("type="))
    }

    @Test func `configs skip parts with an unresolvable object id`() throws {
        // A part the caller can't resolve an id for (shouldn't happen for anything actually packed)
        // is skipped rather than emitting a malformed <object id="..."> entry.
        let entries = SlicerSettingsEntries([(Part("Orphan"), .init(bambu: [.wallLoops: "3"], prusa: [.perimeters: "3"]))])

        #expect(try entries.bambuConfigData(objectID: { _ in nil }, objectName: { _ in nil }) == nil)
        #expect(try entries.prusaConfigData(objectID: { _ in nil }, triangleCount: { _ in 12 }) == nil)
    }

    @Test func `bambu config merges multiple entries resolving to the same id`() throws {
        // Regression: inComponent's own declaration and onPlatter's re-declaration against the final
        // packed part both resolve to the same id whenever packing didn't rename or copy the part
        // (the common quantity == 1, removingMaterials == false case) — this must produce one merged
        // <object> block, not two duplicate ones.
        let entries = SlicerSettingsEntries([
            (Part("A"), .init(bambu: [.wallLoops: "3"])),
            (Part("B"), .init(bambu: [.sparseInfillDensity: "20%"])), // distinct Part, same object id
        ])
        let data = try entries.bambuConfigData(objectID: { _ in 7 }, objectName: { _ in nil })
        let string = try #require(data).utf8String

        #expect(string.components(separatedBy: "<object").count == 2) // one split point == one <object> block
        #expect(string.contains(#"key="wall_loops" value="3""#))
        #expect(string.contains(#"key="sparse_infill_density" value="20%""#))
    }

    @Test func `bambu config carries the object name`() throws {
        // Bambu Studio takes an object's displayed name from this metadata key alone once the object
        // has a config block — the `name` attribute on the 3MF <object> element is never consulted in
        // that branch. Omitting it blanks the name of every component that has settings.
        let entries = SlicerSettingsEntries([(Part("Widget"), .init(bambu: [.wallLoops: "3"]))])
        let data = try entries.bambuConfigData(objectID: { _ in 42 }, objectName: { _ in "Bracket" })
        let string = try #require(data).utf8String

        #expect(string.contains(#"key="name" value="Bracket""#))
    }

    @Test func `an explicit name setting wins over the part's name`() throws {
        let entries = SlicerSettingsEntries([(Part("Widget"), .init(bambu: [.name: "Chosen"]))])
        let data = try entries.bambuConfigData(objectID: { _ in 42 }, objectName: { _ in "Bracket" })
        let string = try #require(data).utf8String

        #expect(string.contains(#"key="name" value="Chosen""#))
        #expect(!string.contains("Bracket"))
    }

    @Test func `prusa config writes a volume spanning the whole mesh`() throws {
        // The load-bearing rule of PrusaSlicer's format: once an <object> block exists, the block's
        // <volume> list *replaces* the default whole-mesh volume. An object written without one loads
        // with no geometry at all.
        let entries = SlicerSettingsEntries([(Part("Widget"), .init(prusa: [.fillDensity: "15%"]))])
        let data = try entries.prusaConfigData(objectID: { _ in 3 }, triangleCount: { _ in 12 })
        let string = try #require(data).utf8String

        #expect(string.contains(#"<object id="3">"#))
        #expect(string.contains(#"<metadata type="object" key="fill_density" value="15%" />"#))
        // Inclusive, 0-based triangle indices: 12 triangles spans 0...11.
        #expect(string.contains(#"<volume firstid="0" lastid="11">"#))
        #expect(string.components(separatedBy: "<volume").count == 2) // exactly one volume per object
    }

    @Test func `prusa config skips objects without a usable triangle count`() throws {
        // A wrong triangle range is worse than no settings: too high and PrusaSlicer refuses to open
        // the file at all, too low and it silently drops the triangles past the end. So an object
        // whose count couldn't be measured is left out entirely rather than guessed at.
        let entries = SlicerSettingsEntries([(Part("Widget"), .init(prusa: [.fillDensity: "15%"]))])

        #expect(try entries.prusaConfigData(objectID: { _ in 3 }, triangleCount: { _ in nil }) == nil)
        #expect(try entries.prusaConfigData(objectID: { _ in 3 }, triangleCount: { _ in 0 }) == nil)
    }
}
