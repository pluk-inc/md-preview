// swift-tools-version:6.0
//
// Local test scaffold for the Quick Look extension's pure-Foundation
// helpers. The Xcode project is the source of truth — `InlineLocalAssets.swift`
// lives at `quick-look/InlineLocalAssets.swift` and is symlinked into
// `Sources/QuickLookHelpers/` so SPM can compile it without duplicating
// the file.
//
// Run: `swift test --package-path tests/swift-tests`
//
import PackageDescription

let package = Package(
    name: "QuickLookHelperTests",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "QuickLookHelpers"),
        .testTarget(
            name: "QuickLookHelperTests",
            dependencies: ["QuickLookHelpers"]
        ),
    ]
)
