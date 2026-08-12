import Foundation
import Cadova
import Sprue
import Zip

// A standalone check of the volume ranges Sprue writes into PrusaSlicer's `Slic3r_PE_model.config`.
//
// It deliberately re-derives everything from the finished 3MF rather than reusing Sprue's own
// bookkeeping: it counts the triangles actually serialized into each object's mesh and applies the
// rules PrusaSlicer's importer enforces (`src/libslic3r/Format/3mf.cpp`). A range that breaks any of
// them either fails the load outright or silently mangles the mesh, and neither is something the
// geometry pipeline itself would notice.

/// The rules PrusaSlicer applies when it reads an object's volume list.
enum Rule: String, CaseIterable {
    /// Once an `<object>` block exists, its `<volume>` list *replaces* the default whole-mesh volume,
    /// so a block without one yields an object with no geometry at all.
    case hasVolume = "object declares at least one volume"
    /// `_generate_volumes`: `geo_tri_count <= last_triangle_id` aborts the load with
    /// "Found invalid triangle id".
    case rangeWithinMesh = "lastid is inside the serialized mesh"
    /// A reversed or empty range trips "An empty triangle mesh found".
    case rangeNonEmpty = "firstid <= lastid, and the range is non-empty"
    /// Not enforced by PrusaSlicer, but triangles outside the union of the volumes are silently
    /// dropped from the object — the failure mode that produces a quietly incomplete print.
    case rangeCoversMesh = "volumes cover every triangle in the mesh"
    /// A config block referring to an object that isn't in the build is ignored, so the settings and
    /// the mesh description would both be lost.
    case objectExists = "object id matches a build item"
}

struct ObjectReport {
    let id: Int
    let triangleCount: Int?
    let volumes: [(firstID: Int, lastID: Int)]
    var failures: [Rule] = []

    var isOK: Bool { failures.isEmpty }
}

struct ArchiveReport {
    let name: String
    let objects: [ObjectReport]
    let hasPrusaConfig: Bool
    let hasBambuConfig: Bool
    let unknownPrusaKeys: [String]

    var isOK: Bool { objects.allSatisfy(\.isOK) && unknownPrusaKeys.isEmpty }
}

// MARK: - Parsing

private extension String {
    /// The value of `name="…"` in this XML fragment, if present.
    func attributeValue(_ name: String) -> String? {
        guard let start = range(of: "\(name)=\"") else { return nil }
        let rest = self[start.upperBound...]
        guard let end = rest.firstIndex(of: "\"") else { return nil }
        return String(rest[..<end])
    }

    /// Every `<tag …>` fragment, each running to the start of the next one.
    func fragments(forTag tag: String) -> [String] {
        Array(components(separatedBy: "<\(tag) ").dropFirst())
    }

    /// The substring from `<object id="N"` up to its closing tag.
    func objectElement(id: Int) -> String? {
        guard let start = range(of: "<object id=\"\(id)\"") else { return nil }
        let rest = self[start.lowerBound...]
        guard let end = rest.range(of: "</object>") else { return String(rest) }
        return String(rest[..<end.upperBound])
    }
}

struct ArchiveInspector {
    static let prusaConfigPath = "Metadata/Slic3r_PE_model.config"
    static let bambuConfigPath = "Metadata/model_settings.config"

    let archive: ZipArchive<Data>

    init(data: Data) throws {
        archive = try ZipArchive(data: data)
    }

    func text(at path: String) throws -> String {
        String(decoding: try archive.fileContents(at: path), as: UTF8.self)
    }

    /// Triangle counts for each build item, counted inside that item's own `<object>` element so a
    /// model file holding more than one object can't inflate the total.
    func serializedTriangleCounts() throws -> [Int: Int] {
        var counts: [Int: Int] = [:]
        for item in try text(at: "3D/3dmodel.model").fragments(forTag: "item") {
            guard let id = item.attributeValue("objectid").flatMap(Int.init) else { continue }
            let path = item.attributeValue("p:path").map { String($0.dropFirst()) } ?? "3D/3dmodel.model"
            guard let element = try text(at: path).objectElement(id: id) else { continue }
            counts[id] = element.fragments(forTag: "triangle").count
        }
        return counts
    }

    /// Object ids in PrusaSlicer's sidecar, each with its declared volume ranges.
    func prusaObjects() throws -> [(id: Int, volumes: [(firstID: Int, lastID: Int)])] {
        try text(at: Self.prusaConfigPath).fragments(forTag: "object").compactMap { object in
            guard let id = object.attributeValue("id").flatMap(Int.init) else { return nil }
            let volumes = object.fragments(forTag: "volume").compactMap { volume -> (Int, Int)? in
                guard let first = volume.attributeValue("firstid").flatMap(Int.init),
                      let last = volume.attributeValue("lastid").flatMap(Int.init)
                else { return nil }
                return (first, last)
            }
            return (id, volumes)
        }
    }

    /// Option keys in the Prusa sidecar that aren't members of PrusaSlicer's per-object config
    /// classes. Any one of these makes PrusaSlicer throw and refuse the whole file.
    func unknownPrusaKeys() throws -> [String] {
        let text = try text(at: Self.prusaConfigPath)
        let keys = text.fragments(forTag: "metadata")
            .filter { $0.attributeValue("type") == "object" }
            .compactMap { $0.attributeValue("key") }
        return keys.filter { PrusaSettingKey(rawValue: $0) == nil }.sorted()
    }

    func hasEntry(at path: String) -> Bool {
        archive.hasEntry(at: path)
    }
}

// MARK: - Checking

struct VolumeRangeChecker {
    static func report(named name: String, data: Data) throws -> ArchiveReport {
        let inspector = try ArchiveInspector(data: data)

        guard inspector.hasEntry(at: ArchiveInspector.prusaConfigPath) else {
            return ArchiveReport(
                name: name,
                objects: [],
                hasPrusaConfig: false,
                hasBambuConfig: inspector.hasEntry(at: ArchiveInspector.bambuConfigPath),
                unknownPrusaKeys: []
            )
        }

        let counts = try inspector.serializedTriangleCounts()
        let objects = try inspector.prusaObjects().map { object -> ObjectReport in
            var report = ObjectReport(id: object.id, triangleCount: counts[object.id], volumes: object.volumes)

            guard let triangleCount = counts[object.id] else {
                report.failures = [.objectExists]
                return report
            }
            if object.volumes.isEmpty {
                report.failures.append(.hasVolume)
                return report
            }
            if object.volumes.contains(where: { $0.lastID >= triangleCount }) {
                report.failures.append(.rangeWithinMesh)
            }
            if object.volumes.contains(where: { $0.firstID < 0 || $0.lastID < $0.firstID }) {
                report.failures.append(.rangeNonEmpty)
            }
            let covered = object.volumes.reduce(into: Set<Int>()) { covered, volume in
                guard volume.firstID <= volume.lastID else { return }
                covered.formUnion(volume.firstID...volume.lastID)
            }
            if covered != Set(0 ..< triangleCount) {
                report.failures.append(.rangeCoversMesh)
            }
            return report
        }

        return ArchiveReport(
            name: name,
            objects: objects.sorted { $0.id < $1.id },
            hasPrusaConfig: true,
            hasBambuConfig: inspector.hasEntry(at: ArchiveInspector.bambuConfigPath),
            unknownPrusaKeys: try inspector.unknownPrusaKeys()
        )
    }

    static func print(_ report: ArchiveReport) {
        Swift.print("── \(report.name)")
        guard report.hasPrusaConfig else {
            Swift.print("   no PrusaSlicer sidecar (bambu sidecar: \(report.hasBambuConfig ? "yes" : "no"))")
            return
        }
        for object in report.objects {
            let ranges = object.volumes.map { "\($0.firstID)…\($0.lastID)" }.joined(separator: ", ")
            let mesh = object.triangleCount.map(String.init) ?? "—"
            let mark = object.isOK ? "ok  " : "FAIL"
            Swift.print("   \(mark) object \(object.id): volumes [\(ranges)]  mesh \(mesh) triangles")
            for failure in object.failures {
                Swift.print("        ✗ \(failure.rawValue)")
            }
        }
        if !report.unknownPrusaKeys.isEmpty {
            Swift.print("   FAIL keys PrusaSlicer would reject: \(report.unknownPrusaKeys.joined(separator: ", "))")
        }
    }
}

// MARK: - Fixtures

// Deliberately varied: different mesh densities, parts renamed by packing, nested parts that are
// emitted as their own objects, disconnected solids split by the packer, and a plain export that
// never goes through onPlatter().
let fixtures: [(name: String, geometry: @Sendable () -> any Geometry3D)] = [
    ("single box, no platter", {
        Box(x: 20, y: 15, z: 10)
            .inComponent(name: "Box", slicerSettings: [.infillDensity(15)])
    }),
    ("box + sphere on platter", {
        Box(x: 20, y: 15, z: 10)
            .inComponent(name: "Box", slicerSettings: [.infillDensity(15)])
            .adding {
                Sphere(radius: 8)
                    .inComponent(name: "Ball", slicerSettings: [.wallCount(4)])
            }
            .onPlatter()
    }),
    ("dense sphere", {
        Sphere(radius: 20)
            .withSegmentation(count: 160)
            .inComponent(name: "Dense", slicerSettings: [.infillDensity(5)])
            .onPlatter()
    }),
    ("multiplied component (quantity 4)", {
        Cylinder(diameter: 14, height: 8).withSegmentation(count: 6)
            .inComponent(name: "Hex", quantity: 4, slicerSettings: [.infillDensity(35)])
            .onPlatter()
    }),
    // Without onPlatter() the nested part survives and is emitted as its own object, so the host's
    // own mesh is *not* the whole of what its geometry contains. This is the case that separates a
    // `.mainPart`-scoped measurement from a `.solidParts` one.
    ("component with a nested part, no platter", {
        Box(x: 20, y: 20, z: 10)
            .adding {
                Sphere(radius: 6)
                    .translated(x: 40)
                    .inPart(Part("Tagalong"))
            }
            .inComponent(name: "Host", slicerSettings: [.infillDensity(15)])
    }),
    ("component with a nested part, on platter", {
        Box(x: 20, y: 20, z: 10)
            .adding {
                Sphere(radius: 6)
                    .translated(x: 40)
                    .inPart(Part("Tagalong"))
            }
            .inComponent(name: "Host", slicerSettings: [.infillDensity(15)])
            .onPlatter()
    }),
    ("disconnected solids, separated", {
        Box(x: 10, y: 10, z: 10)
            .adding { Sphere(radius: 6).translated(x: 40) }
            .inComponent(name: "TwoBodies", slicerSettings: [.infillDensity(25)])
            .onPlatter()
    }),
    ("disconnected solids, kept together", {
        Box(x: 10, y: 10, z: 10)
            .adding { Sphere(radius: 6).translated(x: 40) }
            .inComponent(name: "TwoBodies", slicerSettings: [.infillDensity(25)])
            .onPlatter(separatingParts: false)
    }),
    ("materials stripped (parts renamed)", {
        Box(x: 20, y: 15, z: 10)
            .colored(.red)
            .inComponent(name: "Painted", slicerSettings: [.infillDensity(15)])
            .onPlatter(removingMaterials: true)
    }),
    ("fork-only settings (no prusa sidecar expected)", {
        Box(x: 20, y: 15, z: 10)
            .inComponent(name: "OrcaOnly", slicerSettings: [.zContouringEnabled(true)])
            .onPlatter()
    }),
    ("rotated component (up direction)", {
        Box(x: 12, y: 12, z: 60)
            .inComponent(name: "Pillar", upDirection: .right, slicerSettings: [.wallCount(3)])
            .onPlatter()
    }),
]

var failures = 0
for fixture in fixtures {
    let data = try await ModelFileGenerator.build { fixture.geometry() }.data()
    let report = try VolumeRangeChecker.report(named: fixture.name, data: data)
    VolumeRangeChecker.print(report)
    if !report.isOK { failures += 1 }
}

print("")
if failures == 0 {
    print("All \(fixtures.count) fixtures pass every PrusaSlicer volume rule.")
} else {
    print("\(failures) of \(fixtures.count) fixtures FAILED.")
    exit(1)
}
