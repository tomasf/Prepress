# Sprue

Sprue is a library for [Cadova](https://github.com/tomasf/Cadova) that smooths out the workflow of developing a model for 3D printing.

Writing a model in code makes the model itself easy to change, but the steps around it stay stubbornly manual. Every regeneration means arranging the parts on the bed again, standing up the ones that print on their side, and re-entering the per-object settings you picked last time.

Sprue's goal is to move those steps into code, where each one is expressed once, sits next to the geometry it describes, and stays correct as the design evolves. This is done by per-object slicer settings that travel inside the exported 3MF and apply themselves when the file is opened, and by declaring the printable pieces of a model as *components*, which Sprue orients, multiplies and lays out on a platter. The library is meant to keep growing along those lines, as more of the routine turns out to be worth automating.

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

### Slicer settings

Per-object print settings can be declared on the geometry they belong to. They're written into the exported 3MF, so opening the file applies them per object with no manual configuration in the slicer. `withSlicerSettings` works on any Cadova part, and nothing else in Sprue is needed to use it. List the settings inline, or pass an array where you already have one:

```swift
Box(x: 30, y: 30, z: 10)
    .withSlicerSettings(
        .infill(.gyroid, density: 20),
        .support(.treeAuto),
        .wallCount(4),
    )
    .inPart(name: "Lightweight")
```

The modifier has to be applied *within* the part it configures, as above. Written the other way round (`.inPart(…).withSlicerSettings(…)`) it configures whatever part encloses that one, because a part captures its contents where it's declared and anything chained on afterwards lands outside it. Settings declared on a nested part stay with that part and never reach the part around it.

Settings are slicer-agnostic. Each one knows how to express itself in both config formats Sprue writes: Bambu Studio's, also read by OrcaSlicer, Creality Print and the other Bambu-derived slicers, and PrusaSlicer's, also read by SuperSlicer. Both sidecars go into the same file, and each slicer reads the one it knows.

Not every option exists everywhere. A setting with no equivalent in a slicer is simply left out of that slicer's file, so the object keeps whatever the loaded print profile specifies. Nothing is approximated with a neighboring option that means something subtly different. Anything narrower than universal says so in its documentation, for instance **Bambu Studio and its forks only** or **OrcaSlicer only**.

Grouped factories like `infill(_:density:…)`, `support(_:style:…)`, `brim(_:width:…)` and `ironing(_:flow:…)` set several related options at once. Every parameter beyond the first is optional and unspecified ones are *not written*, leaving your own profile's value intact. Single-option factories mix freely with them, refining one value out of a group:

```swift
.withSlicerSettings(
    .infill(.gyroid, density: 20),
    .infillDensity(50),   // wins; the gyroid pattern is kept
)
```

### Components and the platter

A component is a self-contained printable piece. Declare geometry as one with `inComponent`, then call `onPlatter` on the assembly:

```swift
await Model("Bracket set") {
    Box(x: 40, y: 28, z: 10)
        .inComponent(name: "Block")
        .adding {
            Cylinder(bottomDiameter: 30, topDiameter: 10, height: 20)
                .inComponent(name: "Cone")
        }
        .onPlatter()
}
```

Each component is emitted as its own named part, so they stay individually selectable and movable in the slicer. Geometry that isn't a component, including plain Cadova `inPart` parts, is left off the platter rather than dropped onto the bed in an arbitrary orientation.

A component can carry slicer settings for the whole piece, rather than declaring them on the geometry inside it:

```swift
Box(x: 30, y: 30, z: 10)
    .inComponent(name: "Lightweight", settings: .infill(.gyroid, density: 20))
```

Where a part has settings from both, the two are merged, and `withSlicerSettings` wins for any option the component sets as well, being the more specific of the two.

### Orientation

`upDirection` names the direction, in the geometry's own coordinate system, that should point up while printing. A tall pillar modeled standing up but printed lying down says so once, and `onPlatter` tips it flat:

```swift
Box(x: 12, y: 12, z: 70)
    .inComponent(name: "Pillar", upDirection: .right)
```

Declaring a component also sets Cadova's `naturalUpDirection` environment value for its geometry. Anything inside that reads it, such as circular overhang compensation, is then built for the orientation the part is actually printed in, without having to be told the direction a second time.

### Platter options

A component carries a few settings that only mean anything once it's laid out, grouped into `PlatterOptions`.

The usual way of working is to build the model as it looks assembled, marking each piece as a component where it sits, and put the whole thing on a platter. Several bodies marked with the *same* component merge into one part, so four wheels placed around an assembly arrive as one part holding four disconnected solids. They're laid out individually by default, which is what you want. Set `separateSolids` to `false` to keep a component's solids together as a rigid unit, for a print-in-place hinge or a captive nut:

```swift
hinge
    .inComponent(name: "Hinge", platterOptions: .init(separateSolids: false))
```

`quantity` covers the other case, where the model contains one of something but the print needs several:

```swift
Cylinder(diameter: 26, height: 14).withSegmentation(count: 6)
    .inComponent(name: "Hex", platterOptions: .init(quantity: 4))
```

### Layout

Components are laid out with a no-fit-polygon nester over each one's footprint. The gap between them is the one thing worth tuning:

```swift
.onPlatter()
    .withComponentSpacing(4)  // mm between neighboring parts; defaults to 2
```

`onPlatter(removingMaterials:)` takes one further option: `removingMaterials` strips all colors so the platter prints as one uniform material.

### Assembly view

Flattening a model onto the bed normally throws away the arrangement it started from, leaving a plate of loose parts with nothing recording how they fit together. Sprue writes that arrangement into the 3MF, so Bambu Studio's assembly view can show the model as designed while the plate stays laid out flat.

## License

This project is licensed under the MIT license. See the LICENSE file for details.
