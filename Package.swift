// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "QuotaCritter",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "QuotaCritter", targets: ["QuotaCritter"])],
    targets: [
        .executableTarget(name: "QuotaCritter"),
        .testTarget(name: "QuotaCritterTests", dependencies: ["QuotaCritter"])
    ]
)
