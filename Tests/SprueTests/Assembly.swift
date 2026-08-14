import Foundation
import Testing
import Cadova
import Zip
@testable import Sprue

struct AssemblyTests {
    @Test func `a pose serializes as twelve column-major values`() {
        // Bambu Studio reads the 3×4 affine part column by column. Getting this order wrong produces a
        // matrix that still parses and still looks plausible, so pin it against a transform whose every
        // element is distinguishable.
        let transform = Transform3D([
            [1, 2, 3, 4],
            [5, 6, 7, 8],
            [9, 10, 11, 12],
            [0, 0, 0, 1],
        ])

        #expect(transform.assembleAttributeValue == "1.0 5.0 9.0 2.0 6.0 10.0 3.0 7.0 11.0 4.0 8.0 12.0")
    }

    @Test func `the assembled pose puts a plate part back where it belongs`() async throws {
        // The load-bearing test. A component sitting at an awkward pose in an assembly — rotated about
        // two axes and translated — is flattened onto the plate, and the pose written into the file has
        // to undo exactly that. Applying it to the mesh the file actually stores must reproduce the
        // component's bounds in the original model. A transposed or mis-ordered matrix fails here.
        let component = Component("Block")
        @Sendable func assembly() -> any Geometry3D {
            Box(x: 10, y: 20, z: 30)
                .inComponent(component, upDirection: .right)
                .translated(x: 40, y: 5, z: 7)
                .rotated(z: 30°)
        }

        // Where it sits in the model as designed.
        let capture = BoundsCapture()
        _ = try await ModelFileGenerator.build {
            assembly().evaluating { geometry, evaluator in
                let parts = await evaluator.parts(of: geometry)
                capture.bounds = await evaluator.bounds(of: parts.first { $0.key.name == "Block" }!.value)
                return geometry
            }
        }
        let assembled = try #require(capture.bounds)

        // Where it lands on the plate, and what the file says about putting it back.
        let data = try await ModelFileGenerator.build { assembly().onPlatter() }.data()
        let archive = try ZipArchive(data: data)

        let poses = try archive.assembledPoses()
        #expect(poses.count == 1)
        let objectID = try #require(poses.keys.first)
        let pose = poses[objectID]!

        // Bambu recentres each mesh on its bounding box before applying the pose, so do the same here:
        // testing against the raw vertices would check a transform the slicer never applies.
        let vertices = try archive.vertices(forObject: objectID)
        #expect(vertices.count > 3)
        var meshLow = vertices[0], meshHigh = vertices[0]
        for point in vertices.dropFirst() {
            meshLow = Vector3D.min(meshLow, point)
            meshHigh = Vector3D.max(meshHigh, point)
        }
        let centre = (meshLow + meshHigh) / 2

        let restored = vertices.map { pose.apply(to: $0 - centre) }
        var low = restored[0], high = restored[0]
        for point in restored.dropFirst() {
            low = Vector3D.min(low, point)
            high = Vector3D.max(high, point)
        }

        #expect(abs(low.x - assembled.minimum.x) < 1e-3, "x \(low.x) vs \(assembled.minimum.x)")
        #expect(abs(low.y - assembled.minimum.y) < 1e-3, "y \(low.y) vs \(assembled.minimum.y)")
        #expect(abs(low.z - assembled.minimum.z) < 1e-3, "z \(low.z) vs \(assembled.minimum.z)")
        #expect(abs(high.x - assembled.maximum.x) < 1e-3)
        #expect(abs(high.y - assembled.maximum.y) < 1e-3)
        #expect(abs(high.z - assembled.maximum.z) < 1e-3)
    }

    @Test func `part meshes are stored in plate coordinates`() async throws {
        // The pose above is only correct because a part's mesh means what it says: Cadova no longer
        // peels a transform onto the build item, so there's no second matrix to compose in. If item
        // transforms ever come back, the assembled poses silently become wrong by exactly that matrix.
        let platter = Box(10)
            .inComponent(name: "A")
            .adding { Box(10).translated(x: 60).inComponent(name: "B") }
            .onPlatter()

        let data = try await ModelFileGenerator.build { platter }.data()
        let archive = try ZipArchive(data: data)

        #expect(try archive.hasItemTransforms() == false)

        // Each mesh sits where the plate puts it: resting on z = 0, not at the modelled height.
        for (id, _) in try archive.assembledPoses() {
            let vertices = try archive.vertices(forObject: id)
            let minZ = vertices.map(\.z).min() ?? .infinity
            #expect(abs(minZ) < 1e-6, "object \(id) rests at z = \(minZ)")
        }
    }

    @Test func `every laid-out piece gets a pose`() async throws {
        // One component, two declarations at different orientations, plus a second component. Every
        // piece the platter emits is one Bambu can put back.
        let tube = Component("Tube")
        let platter = Stack(.x, spacing: 1) {
            Cylinder(diameter: 5, height: 50).inComponent(tube).rotated(x: 20°)
            Cylinder(diameter: 6, height: 30).inComponent(tube).rotated(y: -15°)
            Box(10).inComponent(name: "Block")
        }
        .onPlatter()

        let data = try await ModelFileGenerator.build { platter }.data()
        let archive = try ZipArchive(data: data)

        #expect(try archive.assembledPoses().count == 3)
    }
}
