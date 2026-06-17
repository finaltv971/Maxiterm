// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Persistence",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "Persistence", targets: ["Persistence"]),
    ],
    dependencies: [
        .package(path: "../Core"),
    ],
    targets: [
        // Les tests de cette couche (SwiftData) tournent sur simulateur iOS via
        // la cible MaxitermTests ; SwiftData ne s'exécute pas sous `swift test`
        // macOS en ligne de commande.
        .target(name: "Persistence", dependencies: ["Core"]),
    ]
)
