import Foundation
import Cadova
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

    /// Every setting in Bambu Studio's sidecar, per object id, so one object's settings can be
    /// checked without matching on another's.
    func bambuSettings() throws -> [Int: [String: String]] {
        var settings: [Int: [String: String]] = [:]
        for object in try text(at: SlicerSettingsEntries.bambuConfigPath).fragments(forTag: "object") {
            guard let id = object.attributeValue("id").flatMap(Int.init) else { continue }
            settings[id] = object.fragments(forTag: "metadata").reduce(into: [:]) { result, metadata in
                guard let key = metadata.attributeValue("key"),
                      let value = metadata.attributeValue("value")
                else { return }
                result[key] = value
            }
        }
        return settings
    }

    /// The assembled pose Bambu Studio's assembly view reads, per object id.
    ///
    /// Parsed back from the 12 column-major values of the `transform` attribute, so a transposed or
    /// mis-ordered matrix shows up as a wrong pose rather than passing unnoticed.
    func assembledPoses() throws -> [Int: Transform3D] {
        var poses: [Int: Transform3D] = [:]
        for item in try text(at: SlicerSettingsEntries.bambuConfigPath).fragments(forTag: "assemble_item") {
            guard let id = item.attributeValue("object_id").flatMap(Int.init),
                  let values = item.attributeValue("transform")?.split(separator: " ").compactMap({ Double($0) }),
                  values.count == 12
            else { continue }
            func element(_ row: Int, _ column: Int) -> Double { values[column * 3 + row] }
            poses[id] = Transform3D([
                [element(0, 0), element(0, 1), element(0, 2), element(0, 3)],
                [element(1, 0), element(1, 1), element(1, 2), element(1, 3)],
                [element(2, 0), element(2, 1), element(2, 2), element(2, 3)],
                [0, 0, 0, 1],
            ])
        }
        return poses
    }

    /// Every vertex of a build item's mesh, in the coordinates the file stores them in.
    func vertices(forObject id: Int) throws -> [Vector3D] {
        for item in try text(at: "3D/3dmodel.model").fragments(forTag: "item") {
            guard item.attributeValue("objectid").flatMap(Int.init) == id else { continue }
            let path = item.attributeValue("p:path").map { String($0.dropFirst()) } ?? "3D/3dmodel.model"
            return try text(at: path).fragments(forTag: "vertex").compactMap { vertex in
                guard let x = vertex.attributeValue("x").flatMap(Double.init),
                      let y = vertex.attributeValue("y").flatMap(Double.init),
                      let z = vertex.attributeValue("z").flatMap(Double.init)
                else { return nil }
                return Vector3D(x: x, y: y, z: z)
            }
        }
        return []
    }

    /// Whether any build item carries a transform matrix of its own.
    func hasItemTransforms() throws -> Bool {
        try text(at: "3D/3dmodel.model").fragments(forTag: "item")
            .contains { $0.attributeValue("transform") != nil }
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

extension ZipArchive<Data> {
    /// Every mesh in the package, with the name of the object carrying it.
    ///
    /// Scans all model files rather than following build items, so it finds a mesh whether it's an
    /// object in its own right or a volume of a grouped one — the two forms a component's pieces take
    /// depending on whether anything rides inside it. Names repeat when a component was copied.
    func meshes() throws -> [(name: String, vertices: [Vector3D])] {
        var found: [(name: String, vertices: [Vector3D])] = []
        // A mesh lives either in the file a build item points at, or — once a component's pieces are
        // grouped — in one a component references. Follow both.
        let root = try text(at: "3D/3dmodel.model")
        let referenced = (root.fragments(forTag: "item") + root.fragments(forTag: "component"))
            .compactMap { $0.attributeValue("p:path").map { String($0.dropFirst()) } }
        let paths = ["3D/3dmodel.model"] + referenced

        for path in Set(paths) {
            for object in try text(at: path).fragments(forTag: "object") {
                let mesh = object.components(separatedBy: "</object>").first ?? object
                let vertices = mesh.fragments(forTag: "vertex").compactMap { vertex -> Vector3D? in
                    guard let x = vertex.attributeValue("x").flatMap(Double.init),
                          let y = vertex.attributeValue("y").flatMap(Double.init),
                          let z = vertex.attributeValue("z").flatMap(Double.init)
                    else { return nil }
                    return Vector3D(x: x, y: y, z: z)
                }
                guard !vertices.isEmpty, let name = object.attributeValue("name") else { continue }
                found.append((name, vertices))
            }
        }
        return found
    }

    /// The axis-aligned bounds of every mesh, by object name.
    func meshBounds() throws -> [(name: String, low: Vector3D, high: Vector3D)] {
        try meshes().map { mesh in
            var low = mesh.vertices[0], high = mesh.vertices[0]
            for point in mesh.vertices.dropFirst() {
                low = Vector3D.min(low, point)
                high = Vector3D.max(high, point)
            }
            return (mesh.name, low, high)
        }
    }
}
