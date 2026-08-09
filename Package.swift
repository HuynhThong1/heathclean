// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HeathFirstKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Domain", targets: ["Domain"])
    ],
    targets: [
        .target(name: "Domain"),
        .executableTarget(name: "DomainCheck", dependencies: ["Domain"])
    ]
)
