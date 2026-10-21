// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "HandMouse",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "HandMouse", targets: ["HandMouse"])
    ],
    targets: [
        .executableTarget(
            name: "HandMouse",
            path: "Sources/HandMouse"
        ),
        .testTarget(
            name: "HandMouseTests",
            dependencies: ["HandMouse"],
            path: "Tests/HandMouseTests"
        )
    ]
)
