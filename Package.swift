// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Fabricate",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "Fabricate", targets: ["Fabricate"]),
        .executable(name: "generator", targets: ["generator"]),
    ],
    dependencies: [
        .package(path: "../Cadova"),
        .package(url: "https://github.com/tomasf/Nodal.git", from: "1.0.1"),
    ],
    targets: [
        .target(
            name: "Fabricate",
            dependencies: ["Cadova", .product(name: "Nodal", package: "Nodal")],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
        .executableTarget(
            name: "generator",
            dependencies: ["Fabricate", "Cadova"],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
        .testTarget(
            name: "FabricateTests",
            dependencies: ["Fabricate", "Cadova"],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
    ]
)
