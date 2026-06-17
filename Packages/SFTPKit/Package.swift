// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SFTPKit",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "SFTPKit", targets: ["SFTPKit"]),
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../SSHKit"),
    ],
    targets: [
        .target(name: "SFTPKit", dependencies: ["Core", "SSHKit"]),
        .testTarget(name: "SFTPKitTests", dependencies: ["SFTPKit", "Core"]),
    ]
)
