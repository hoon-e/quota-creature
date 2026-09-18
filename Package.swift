// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "QuotaCreature",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "QuotaCreature", targets: ["QuotaCritter"])],
    targets: [
        .executableTarget(name: "QuotaCritter"),
        .testTarget(name: "QuotaCritterTests", dependencies: ["QuotaCritter"])
    ]
)
