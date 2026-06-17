// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SSHKit",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "SSHKit", targets: ["SSHKit"]),
    ],
    dependencies: [
        // 100% Apple, aucune dépendance forkée : la couche SSH la plus sensible
        // repose uniquement sur des paquets officiels et auditables.
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.81.0"),
        .package(url: "https://github.com/apple/swift-nio-ssh.git", from: "0.9.0"),
        // swift-crypto : parsing de clé Ed25519 (Curve25519). Plage alignée sur
        // celle de swift-nio-ssh pour une résolution unifiée.
        .package(url: "https://github.com/apple/swift-crypto.git", "2.0.0" ..< "5.0.0"),
        .package(path: "../Core"),
    ],
    targets: [
        .target(
            name: "SSHKit",
            dependencies: [
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOConcurrencyHelpers", package: "swift-nio"),
                .product(name: "NIOSSH", package: "swift-nio-ssh"),
                .product(name: "Crypto", package: "swift-crypto"),
                "Core",
            ]
        ),
        .testTarget(
            name: "SSHKitTests",
            dependencies: [
                "SSHKit",
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOEmbedded", package: "swift-nio"),
                .product(name: "NIOSSH", package: "swift-nio-ssh"),
                .product(name: "Crypto", package: "swift-crypto"),
            ]
        ),
    ]
)
