// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Sprue",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "Sprue", targets: ["Sprue"]),
        .executable(name: "generator", targets: ["generator"]),
        .executable(name: "volume-check", targets: ["volume-check"]),
    ],
    dependencies: [
        .package(path: "../Cadova"),
        .package(url: "https://github.com/tomasf/Nodal.git", from: "1.0.1"),
        // Test-only: lets the slicer-config tests read back the 3MF they just wrote.
        .package(url: "https://github.com/tomasf/Zip.git", from: "2.1.2"),
    ],
    targets: [
        .target(
            name: "Sprue",
            dependencies: ["Cadova", .product(name: "Nodal", package: "Nodal")],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
        .executableTarget(
            name: "generator",
            dependencies: ["Sprue", "Cadova"],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
        .executableTarget(
            name: "volume-check",
            dependencies: ["Sprue", "Cadova", .product(name: "Zip", package: "Zip")],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
        .testTarget(
            name: "SprueTests",
            dependencies: ["Sprue", "Cadova", .product(name: "Zip", package: "Zip")],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
    ]
)
