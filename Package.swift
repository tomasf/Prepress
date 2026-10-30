// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Prepress",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "Prepress", targets: ["Prepress"]),
    ],
    dependencies: [
        // Local while `ModelArchive.mainPart` is only on Cadova's dev branch. Swap back to
        // `.package(url: "https://github.com/tomasf/Cadova.git", from: "<version>")` once a release
        // carries it — this path dependency can't be released, and it keeps Cadova out of
        // Package.resolved in the meantime.
        .package(path: "../Cadova"),
        .package(url: "https://github.com/tomasf/Nodal.git", from: "1.0.3"),
        .package(url: "https://github.com/tomasf/ThreeMF.git", from: "0.3.3"),
        // Test-only: lets the slicer-config tests read back the 3MF they just wrote.
        .package(url: "https://github.com/tomasf/Zip.git", from: "2.1.3"),
    ],
    targets: [
        .target(
            name: "Prepress",
            dependencies: [
                "Cadova",
                .product(name: "Nodal", package: "Nodal"),
                .product(name: "ThreeMF", package: "ThreeMF"),
            ],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
        .testTarget(
            name: "PrepressTests",
            dependencies: ["Prepress", "Cadova", .product(name: "Zip", package: "Zip")],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
    ]
)
