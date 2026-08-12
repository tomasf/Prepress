# Sprue

Sprue is a library for [Cadova](https://github.com/tomasf/Cadova) that prepares a model for printing. Mark the printable pieces of your model as *components*, and Sprue stands each one the right way up, multiplies it, and packs them all onto a single platter. Per-object slicer settings are embedded in the exported 3MF, so they apply themselves when the file is opened.

A model normally has to be arranged by hand in the slicer every time it's regenerated. Sprue moves that arrangement into the model, where it lives alongside the geometry and stays correct as the design changes.

## Installation

Integrate Sprue into your project with the Swift Package Manager by adding it as a dependency in your `Package.swift` file:

```swift
.package(url: "https://github.com/tomasf/Sprue.git", .upToNextMinor(from: "0.1.0"))
```

Then, import Sprue where it's needed:
```swift
import Sprue
```

## Usage

### Components and the platter

A component is a self-contained printable piece. Declare geometry as one with `inComponent`, then call `onPlatter` on the assembly:

```swift
await Model("Bracket set") {
    Union {
        Box(x: 40, y: 28, z: 10)
            .inComponent(name: "Block")

        Cylinder(bottomDiameter: 30, topDiameter: 10, height: 20)
            .inComponent(name: "Cone")
    }
    .onPlatter()
}
```

Each component is emitted as its own named part, so they stay individually selectable and movable in the slicer. Geometry that isn't a component, including plain Cadova `inPart` parts, is left off the platter rather than dropped onto the bed in an arbitrary orientation.

### Orientation

`upDirection` names the direction, in the geometry's own coordinate system, that should point up while printing. A tall pillar modeled standing up but printed lying down says so once, and `onPlatter` tips it flat:

```swift
Box(x: 12, y: 12, z: 70)
    .inComponent(name: "Pillar", upDirection: .right)
```

This also feeds Cadova's overhang compensation inside the component, so features are built for the orientation they're actually printed in.

### Multiple copies

A component that's needed more than once produces that many copies on the platter, each packed and named separately:

```swift
Cylinder(diameter: 26, height: 14).withSegmentation(count: 6)
    .inComponent(name: "Hex", quantity: 4)
```

### Slicer settings

Components can carry per-object print settings. These are written into the 3MF, so opening the file applies them per object with no manual configuration:

```swift
Box(x: 30, y: 30, z: 10)
    .inComponent(name: "Lightweight", slicerSettings: [
        .infill(.gyroid, density: 20),
        .support(.treeAuto),
        .wallCount(4),
    ])
```

Settings are slicer-agnostic. Each one knows how to express itself in both config formats Sprue writes: Bambu Studio's, also read by OrcaSlicer, Creality Print and the other Bambu-derived slicers, and PrusaSlicer's, also read by SuperSlicer. Both sidecars go into the same file, and each slicer reads the one it knows.

Not every option exists everywhere. A setting with no equivalent in a slicer is simply left out of that slicer's file, so the object keeps whatever the loaded print profile specifies. Nothing is approximated with a neighboring option that means something subtly different. Anything narrower than universal says so in its documentation, for instance **Bambu Studio and its forks only** or **OrcaSlicer only**.

Grouped factories like `infill(_:density:…)`, `support(_:style:…)`, `brim(_:width:…)` and `ironing(_:flow:…)` set several related options at once. Every parameter beyond the first is optional and unspecified ones are *not written*, leaving your own profile's value intact. Single-option factories mix freely with them, refining one value out of a group:

```swift
slicerSettings: [
    .infill(.gyroid, density: 20),
    .infillDensity(50),   // wins; the gyroid pattern is kept
]
```

For options with no factory, `raw(bambu:_:)` and `raw(prusa:_:)` take a key directly.

### Packing

Packing uses a no-fit-polygon nester over each component's footprint. Two environment modifiers tune it:

```swift
.onPlatter()
    .withPackingMargin(2)         // mm grown around each footprint; neighbors end up ~2× this apart
    .withPackingRotationCount(8)  // rotations tried per piece; tighter, but slower
```

`onPlatter(removingMaterials:separatingParts:)` takes two further options. `removingMaterials` strips all colors so the platter prints as one uniform material, and `separatingParts` (on by default) packs a component's disconnected solids individually, which nests tighter than keeping them as one rigid unit.

Arrays of plain geometry can be packed directly with `packed()`, without involving components.

## License

This project is licensed under the MIT license.
