// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CLIDE",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.2.0"),
    ],
    targets: [
        .executableTarget(
            name: "CLIDE",
            dependencies: ["SwiftTerm"],
            path: "Sources"
        ),
        .testTarget(
            name: "CLIDETests",
            dependencies: ["CLIDE"],
            path: "Tests"
        ),
    ]
)
