// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TerminalUI",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "TerminalUI", targets: ["TerminalUI"]),
    ],
    dependencies: [
        // SwiftTerm : émulateur de terminal natif (MIT).
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.13.0"),
    ],
    targets: [
        .target(
            name: "TerminalUI",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm"),
            ]
        ),
    ]
)
