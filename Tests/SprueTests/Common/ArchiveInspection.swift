import Foundation
import Zip
@testable import Sprue

extension Data {
    var utf8String: String { String(decoding: self, as: UTF8.self) }
}

extension String {
    /// The value of `name="…"` in this XML fragment, if present.
    func attributeValue(_ name: String) -> String? {
        guard let start = range(of: "\(name)=\"") else { return nil }
        let rest = self[start.upperBound...]
        guard let end = rest.firstIndex(of: "\"") else { return nil }
        return String(rest[..<end])
    }

    /// Every `<tag …>` fragment in this document, each running up to the next one.
    func fragments(forTag tag: String) -> [String] {
        Array(components(separatedBy: "<\(tag) ").dropFirst())
    }
}

extension ZipArchive<Data> {
    func text(at path: String) throws -> String {
        try fileContents(at: path).utf8String
    }

    /// The number of triangles actually serialized for each build item, keyed by the same object id
    /// the config sidecars reference.
    func serializedTriangleCounts() throws -> [Int: Int] {
        var counts: [Int: Int] = [:]
        for item in try text(at: "3D/3dmodel.model").fragments(forTag: "item") {
            guard let id = item.attributeValue("objectid").flatMap(Int.init) else { continue }
            // Parts each get their own model file; a lone object stays inline in the root model.
            let path = item.attributeValue("p:path").map { String($0.dropFirst()) } ?? "3D/3dmodel.model"
            counts[id] = try text(at: path).fragments(forTag: "triangle").count
        }
        return counts
    }

    /// The `name` attribute Cadova wrote on each build item's `<object>` element, keyed by object id.
    /// This is the name a slicer shows for an object that has no config block of its own.
    func modelObjectNames() throws -> [Int: String] {
        var names: [Int: String] = [:]
        for item in try text(at: "3D/3dmodel.model").fragments(forTag: "item") {
            guard let id = item.attributeValue("objectid").flatMap(Int.init) else { continue }
            let path = item.attributeValue("p:path").map { String($0.dropFirst()) } ?? "3D/3dmodel.model"
            let object = try text(at: path).fragments(forTag: "object")
                .first { $0.attributeValue("id").flatMap(Int.init) == id }
            names[id] = object?.attributeValue("name")
        }
        return names
    }

    /// The `name` metadata in Bambu Studio's sidecar, keyed by object id. Bambu takes an object's
    /// displayed name from here alone once the object has a config block.
    func bambuObjectNames() throws -> [Int: String] {
        var names: [Int: String] = [:]
        for object in try text(at: SlicerSettingsEntries.bambuConfigPath).fragments(forTag: "object") {
            guard let id = object.attributeValue("id").flatMap(Int.init) else { continue }
            names[id] = object.fragments(forTag: "metadata")
                .first { $0.attributeValue("key") == "name" }?
                .attributeValue("value")
        }
        return names
    }

    /// Each object id in PrusaSlicer's sidecar, paired with the `firstid`/`lastid` of its volume.
    func prusaVolumeRanges() throws -> [Int: (firstID: Int, lastID: Int)] {
        var ranges: [Int: (Int, Int)] = [:]
        for object in try text(at: SlicerSettingsEntries.prusaConfigPath).fragments(forTag: "object") {
            guard let id = object.attributeValue("id").flatMap(Int.init),
                  let volume = object.fragments(forTag: "volume").first,
                  let first = volume.attributeValue("firstid").flatMap(Int.init),
                  let last = volume.attributeValue("lastid").flatMap(Int.init)
            else { continue }
            ranges[id] = (first, last)
        }
        return ranges
    }
}
