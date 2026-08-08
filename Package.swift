// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Sprue",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "Sprue", targets: ["Sprue"]),
        .executable(name: "generator", targets: ["generator"]),
    ],
    dependencies: [
        .package(path: "../Cadova"),
        .package(url: "https://github.com/tomasf/Nodal.git", from: "1.0.1"),
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
        .testTarget(
            name: "SprueTests",
            dependencies: ["Sprue", "Cadova"],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
    ]
)
