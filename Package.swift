// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StickyNotes",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "StickyNotes", targets: ["StickyNotes"]),
    ],
    targets: [
        .executableTarget(
            name: "StickyNotes",
            path: "Sources/StickyNotes"
        ),
    ]
)
