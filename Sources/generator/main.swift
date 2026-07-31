import Foundation
import Cadova
import Fabricate

// A set of printable components. Each declares which way is "up" for printing; `onPlatter` stands them
// up accordingly, drops them to the bed, and packs them — keeping each as its own named part.
@GeometryBuilder3D
func components() -> any Geometry3D {
    Box(x: 40, y: 28, z: 10)
        .asComponent(name: "Block")

    Cylinder(diameter: 34, height: 12)
        .asComponent(name: "Disc")

    Cylinder(bottomDiameter: 30, topDiameter: 10, height: 20)
        .asComponent(name: "Cone")

    // Four of these are needed, so one component produces four copies on the platter.
    Cylinder(diameter: 26, height: 14).withSegmentation(count: 6)
        .asComponent(name: "Hex", quantity: 4)

    // A tall pillar that should be printed lying on its side: its +X face points up while printing,
    // so `onPlatter` tips it down flat before packing.
    Box(x: 12, y: 12, z: 70)
        .asComponent(name: "Pillar", upDirection: .right)

    Sphere(radius: 13)
        .asComponent(name: "Dome")
}

// Two otherwise-identical blocks, distinguished only by their declared slicer settings. Bambu Studio
// and its forks (OrcaSlicer, etc.) read these from the platter's embedded model_settings.config and
// apply them automatically per object — no manual per-object configuration needed in the slicer.
@GeometryBuilder3D
func infillDemoComponents() -> any Geometry3D {
    Box(x: 30, y: 30, z: 10)
        .asComponent(name: "Sparse Infill (10%)", slicerSettings: [.sparseInfillDensity(10)])

    Box(x: 30, y: 30, z: 10)
        .asComponent(name: "Dense Infill (80%)", slicerSettings: [.sparseInfillDensity(80)])

    // Exercises a broader mix of typed settings: an enum pattern, a bool, and an int, alongside percent.
    Box(x: 30, y: 30, z: 10)
        .asComponent(name: "Gyroid + Support", slicerSettings: [
            .sparseInfillPattern(.gyroid),
            .sparseInfillDensity(20),
            .wallLoops(4),
            .enableSupport(true),
        ])

    // Fork-specific settings: OrcaSlicer's Z-contouring and Creality Print's tree-support pattern.
    Box(x: 30, y: 30, z: 10)
        .asComponent(name: "Fork Extensions", slicerSettings: [
            .zContouringEnabled(true),
            .supportBasePatternTree(.honeycomb),
        ])
}

await Project(packageRelative: "Models") {
    Metadata(
        title: "Platter Packer",
        description: "Printable components laid out and packed on a platter",
        author: "Tomas Wincent Franzén",
        license: "MIT"
    )

    await Model("Components on platter") {
        components()
            .onPlatter()
            .withPackingMargin(2)
    }

    await Model("Different Infill Demo") {
        infillDemoComponents()
            .onPlatter()
            .withPackingMargin(2)
    }
}
