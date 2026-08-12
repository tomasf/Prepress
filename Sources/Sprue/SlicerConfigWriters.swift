import Foundation
@_spi(ArchiveFinalizer) import Cadova
internal import Nodal

/// Accumulates every component's settings across the geometry tree, so both config sidecars can be
/// assembled once when the archive is finalized.
///
/// A component declares its settings twice — once where it's created, and again against the part
/// packing actually emitted it into — so entries for the same part are merged rather than replaced.
struct SlicerSettingsEntries: ResultElement {
    typealias Entry = (part: Part, settings: ResolvedSlicerSettings)

    var entries: [Entry]

    init() { entries = [] }
    init(_ entries: [Entry]) { self.entries = entries }
    init(combining elements: [SlicerSettingsEntries]) {
        entries = elements.flatMap(\.entries)
    }

    /// One merged settings value per part, later entries winning per key.
    var settingsByPart: [Part: ResolvedSlicerSettings] {
        entries.reduce(into: [:]) { result, entry in
            var merged = result[entry.part] ?? ResolvedSlicerSettings()
            merged.bambu.merge(entry.settings.bambu) { _, new in new }
            merged.prusa.merge(entry.settings.prusa) { _, new in new }
            result[entry.part] = merged
        }
    }
}

// MARK: - Archive integration

extension SlicerSettingsEntries {
    /// Location of Bambu Studio's sidecar within the 3MF archive. Read by Bambu Studio, OrcaSlicer,
    /// Creality Print and the other Bambu-derived vendor slicers.
    static let bambuConfigPath = "Metadata/model_settings.config"

    /// Location of PrusaSlicer's sidecar within the 3MF archive. Read by PrusaSlicer and SuperSlicer.
    ///
    /// The two files never collide: no Bambu-lineage slicer reads this path, and neither PrusaSlicer
    /// nor SuperSlicer reads Bambu's.
    static let prusaConfigPath = "Metadata/Slic3r_PE_model.config"

    /// Writes both sidecars, skipping either one that has nothing to say.
    ///
    /// Each is guarded by a `fileExists` check because finalizers are registered per component, so
    /// several of them run for a model with several configured components.
    static func writeConfigsIfNeeded(to archive: ModelArchive) async throws {
        let accumulated = archive.resultElement(Self.self)

        if !archive.fileExists(at: bambuConfigPath) {
            let names = archive.objectNames
            if let data = try accumulated.bambuConfigData(
                objectID: archive.objectID(for:),
                objectName: { names[$0] }
            ) {
                try archive.addFile(at: bambuConfigPath, data: data)
            }
        }

        guard !archive.fileExists(at: prusaConfigPath) else { return }
        let triangleCounts = await accumulated.triangleCounts(in: archive)
        if let data = try accumulated.prusaConfigData(
            objectID: archive.objectID(for:),
            triangleCount: { triangleCounts[$0] }
        ) {
            try archive.addFile(at: prusaConfigPath, data: data)
        }
    }

    /// Reads the triangle count of each configured part's serialized mesh.
    ///
    /// The scope matters: Cadova writes each part's own node to the 3MF without the parts nested
    /// inside it, which is exactly what `.mainPart` measures. The default `.solidParts` scope would
    /// add those nested parts back in and overstate the count — which PrusaSlicer rejects outright.
    private func triangleCounts(in archive: ModelArchive) async -> [Part: Int] {
        let configured = settingsByPart.filter { !$0.value.prusa.isEmpty }
        guard !configured.isEmpty else { return [:] }

        let geometries = await archive.evaluator.parts(of: archive.rootGeometry, ofType: .solid)

        var counts: [Part: Int] = [:]
        for part in configured.keys {
            guard let geometry = geometries[part] else { continue }
            counts[part] = await archive.evaluator.measurements(of: geometry, scope: .mainPart).triangleCount
        }
        return counts
    }
}

private extension ModelArchive {
    /// The name written into each emitted object's `name` attribute, keyed by its 3MF object id.
    ///
    /// Taken from the parts actually written rather than from the parts our settings were declared
    /// against, so the names in the config can't drift from the ones in the model — packing renames
    /// and copies parts, and only the emitted part's name reaches the file.
    var objectNames: [Int: String] {
        parts.reduce(into: [:]) { names, part in
            if let id = objectID(for: part) {
                names[id] = part.name
            }
        }
    }
}

// MARK: - Building the config files

extension SlicerSettingsEntries {
    /// Builds Bambu Studio's `model_settings.config`, or `nil` when no part contributed anything to
    /// it. Parts whose id can't be resolved (shouldn't happen for parts that were actually packed)
    /// are skipped rather than guessed at.
    ///
    /// Each object also carries a `name`, which is not a print setting but is load-bearing anyway:
    /// Bambu Studio's reader takes an object's displayed name from this key alone once the object has
    /// a config block, ignoring the `name` attribute on the 3MF `<object>` element it would otherwise
    /// use. Without it, configuring a component would blank its name in the object list. An explicit
    /// ``BambuSettingKey/name`` in the settings wins over the part's own name.
    func bambuConfigData(objectID: (Part) -> Int?, objectName: (Int) -> String?) throws -> Data? {
        var settingsByID: [Int: [BambuSettingKey: String]] = [:]
        for (part, settings) in settingsByPart {
            guard !settings.bambu.isEmpty, let id = objectID(part) else { continue }
            settingsByID[id, default: [:]].merge(settings.bambu) { _, new in new }
        }
        guard !settingsByID.isEmpty else { return nil }

        let document = Document()
        let config = document.makeDocumentElement(name: "config")
        for id in settingsByID.keys.sorted() {
            var settings = settingsByID[id]!
            if let name = objectName(id) {
                settings[.name] = settings[.name] ?? name
            }

            let object = config.addElement("object")
            object[attribute: "id"] = String(id)
            object.addMetadata(settings, type: nil)
        }
        return try document.xmlData()
    }

    /// Builds PrusaSlicer's `Slic3r_PE_model.config`, or `nil` when no part contributed anything to it.
    ///
    /// Unlike Bambu's format, this one also has to describe each object's mesh. Once an `<object>`
    /// block exists, PrusaSlicer stops treating the whole mesh as the object's single volume and uses
    /// the block's `<volume>` list instead, so an object we write settings for without a volume would
    /// load with no geometry at all. The triangle range must match the serialized mesh exactly: too
    /// high and PrusaSlicer refuses to open the file, too low and it silently drops the triangles past
    /// the end. A part whose count is unavailable is therefore left out entirely — no settings at all
    /// beats a mangled object.
    func prusaConfigData(objectID: (Part) -> Int?, triangleCount: (Part) -> Int?) throws -> Data? {
        var objects: [Int: (settings: [PrusaSettingKey: String], triangleCount: Int)] = [:]
        for (part, settings) in settingsByPart {
            guard !settings.prusa.isEmpty,
                  let id = objectID(part),
                  let count = triangleCount(part),
                  count > 0
            else { continue }

            var merged = objects[id]?.settings ?? [:]
            merged.merge(settings.prusa) { _, new in new }
            objects[id] = (merged, count)
        }
        guard !objects.isEmpty else { return nil }

        let document = Document()
        let config = document.makeDocumentElement(name: "config")
        for id in objects.keys.sorted() {
            let entry = objects[id]!
            let object = config.addElement("object")
            object[attribute: "id"] = String(id)
            object.addMetadata(entry.settings, type: "object")

            let volume = object.addElement("volume")
            volume[attribute: "firstid"] = "0"
            volume[attribute: "lastid"] = String(entry.triangleCount - 1)
            let volumeType = volume.addElement("metadata")
            volumeType[attribute: "type"] = "volume"
            volumeType[attribute: "key"] = "volume_type"
            volumeType[attribute: "value"] = "ModelPart"
        }
        return try document.xmlData()
    }
}

private extension Node {
    /// Adds one `<metadata>` child per key, sorted by config key so the output is deterministic.
    /// PrusaSlicer needs a `type` discriminator on each; Bambu Studio's format has no such attribute.
    func addMetadata<Key: RawRepresentable<String>>(_ settings: [Key: String], type: String?) {
        for (key, value) in settings.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            let metadata = addElement("metadata")
            if let type {
                metadata[attribute: "type"] = type
            }
            metadata[attribute: "key"] = key.rawValue
            metadata[attribute: "value"] = value
        }
    }
}
