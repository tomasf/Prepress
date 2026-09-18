import Foundation
@_spi(ArchiveFinalizer) import Cadova
internal import ThreeMF
internal import Nodal

/// Rewrites the exported model so each component and the parts riding inside it arrive as one object
/// made of several volumes.
///
/// Cadova writes every part as its own object with its own build item, which is right for parts that
/// stand alone and wrong for one that belongs inside another. A slicer drops each object it loads onto
/// the bed — Bambu Studio's `ModelObject::ensure_on_bed` pushes any single-volume object down until it
/// touches z = 0 — so pips emitted as an object of their own land beside their die rather than in it.
/// An object with *several* volumes is exempt from that, which is what makes this necessary rather
/// than merely tidier.
///
/// The shape being built, in `3D/3dmodel.model`:
///
/// ```xml
/// <object id="9001" type="model">
///   <components>
///     <component objectid="5" p:path="/3D/die-1.model"/>   <!-- the host's own mesh -->
///     <component objectid="9" p:path="/3D/pips.model"/>     <!-- riding inside it -->
///   </components>
/// </object>
/// <build><item objectid="9001" .../></build>
/// ```
///
/// The sub-objects stay in the per-part model files Cadova already wrote; only the root gains the
/// parent and loses the separate build items. Bambu resolves a component's `p:path` against the root
/// (`bbs_3mf.cpp`, `_handle_start_component`), so the parent has to live there — inside a sub-model the
/// path is ignored and the reference would dangle.
struct PartGroupWriter {
    static let rootModelPath = "3D/3dmodel.model"

    /// What one host became: the object the slicer now sees, and the volumes inside it.
    struct Group {
        /// The id of the new parent object, which is what everything about the host now refers to.
        var parentObjectID: Int
        /// The host's own mesh, still an object in its own file, now a volume of the parent.
        var hostSubObjectID: Int
        /// Per passenger, the sub-object id its volume is known by.
        var passengerSubObjectIDs: [Part: Int]
    }

    /// Groups every host with its passengers, rewriting the root model in place.
    ///
    /// - Returns: What each host became, or an empty result when there's nothing to group — in which
    ///   case the model file is left exactly as Cadova wrote it.
    static func regroup(in archive: ModelArchive) throws -> [Part: Group] {
        let grouping = archive.resultElement(PartGrouping.self).passengersByHost
        guard !grouping.isEmpty else { return [:] }
        guard let data = archive.contents(at: rootModelPath) else { return [:] }

        var model = try Model(from: Document(data: data).documentElement!)

        // Build items, by the object id they point at, so a part can be traced to the item that
        // carries its path.
        var itemsByObjectID: [Int: ThreeMF.Item] = [:]
        for item in model.build.items {
            itemsByObjectID[item.objectID] = item
        }

        // Parent ids have to avoid the ones already in play. Only the root's own resource ids could
        // actually collide — a sub-object is addressed as (path, id) — but staying clear of every id in
        // the file costs nothing and leaves the result easier to read.
        var nextID = (model.build.items.map(\.objectID).max() ?? 0) + 1
        var groups: [Part: Group] = [:]
        var consumed: Set<Int> = []

        for (host, passengers) in grouping.sorted(by: { $0.key.name < $1.key.name }) {
            guard let hostID = archive.objectID(for: host), let hostItem = itemsByObjectID[hostID] else {
                continue
            }
            let passengerIDs = passengers.compactMap { passenger in
                archive.objectID(for: passenger).map { (part: passenger, id: $0) }
            }
            guard !passengerIDs.isEmpty else { continue }

            // The host's mesh first, so the volume order matches the order the pieces were declared in.
            let members = [(part: host, id: hostID)] + passengerIDs
            let components = members.map { member in
                ThreeMF.Component(
                    objectID: member.id,
                    transform: nil,
                    path: itemsByObjectID[member.id]?.path
                )
            }

            let parentID = nextID
            nextID += 1
            model.resources.resources.append(ThreeMF.Object(
                id: parentID,
                type: .model,
                name: host.name,
                content: .components(components)
            ))

            // One item where there were several. The host's own item attributes carry over, so the
            // printable flag and the part semantic Cadova wrote survive the regrouping.
            var item = hostItem
            item.objectID = parentID
            item.path = nil
            item.uuid = UUID()
            model.build.items.append(item)

            consumed.formUnion(members.map(\.id))
            groups[host] = Group(
                parentObjectID: parentID,
                hostSubObjectID: hostID,
                passengerSubObjectIDs: Dictionary(
                    uniqueKeysWithValues: passengerIDs.map { ($0.part, $0.id) }
                )
            )
        }

        guard !groups.isEmpty else { return [:] }
        // The pieces that were folded into a parent stop being objects of their own.
        model.build.items.removeAll { consumed.contains($0.objectID) && $0.path != nil }

        try archive.addFile(
            at: rootModelPath,
            data: model.xmlDocument().xmlData(options: .raw)
        )
        return groups
    }
}
