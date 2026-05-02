# Sparkle Integration

Sparkle is the standard framework for over-the-air updates in macOS apps. Amore generates and manages the `appcast.xml` feed that Sparkle reads, and signs each release with EdDSA keys.

## Adding Sparkle to Your Project

### 1. Add the Package Dependency

In Xcode: File > Add Packages > enter `https://github.com/sparkle-project/Sparkle`

Or in `Package.swift`:
```swift
.package(url: "https://github.com/sparkle-project/Sparkle", from: "2.8.1"),
```

### 2. Configure Info.plist

Add these two entries (values are shown in Amore's Sparkle settings):

| Key | Description |
|-----|-------------|
| `SUFeedURL` | URL to your `appcast.xml` feed |
| `SUPublicEDKey` | Your Ed25519 public key (base64) |

### 3. Initialize the Updater

In your SwiftUI `@main` app:

```swift
import SwiftUI
import Sparkle

@main
struct MyApp: App {
    let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    updaterController.updater.checkForUpdates()
                }
            }
        }
    }
}
```

For AppDelegate-based apps, initialize `SPUStandardUpdaterController` in `applicationDidFinishLaunching`.

## Key Management

Amore stores EdDSA signing keys in the macOS keychain, one private key per app.

- **During `amore setup`**: Choose to generate a new key or import an existing one
- **CLI flags**: `--generate-sparkle-key` or `--sparkle-key <base64-private-key>`
- **Signing**: `amore sign <path>` signs an archive with the stored key
- **Verifying**: `amore verify <path> <signature> <public-key>` verifies a signature

**Back up your private keys in a password manager.** If the private key is lost, existing users will not be able to verify future updates — there is no way to recover it. Do this immediately after key generation.

## App Sandbox

Sparkle requires extra setup when using the `com.apple.security.app-sandbox` entitlement.

### Required Info.plist Entry

```xml
<key>SUEnableInstallerLauncherService</key>
<true/>
```

### Required Entitlements

```xml
<!-- Allow Sparkle's XPC installer services -->
<key>com.apple.security.temporary-exception.mach-lookup.global-name</key>
<array>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)-spks</string>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)-spki</string>
</array>

<!-- Allow network access for downloading updates -->
<key>com.apple.security.network.client</key>
<true/>
```

### Alternative: Skip Sandboxing

For simplicity, you can remove the App Sandbox entitlement and use only the Hardened Runtime entitlement instead. Hardened Runtime is required for notarization regardless.

## Troubleshooting

**"An error occurred in retrieving update information"** — This usually means:
- The App Sandbox entitlement is enabled but the XPC services and entitlements above are missing
- The `SUFeedURL` in Info.plist is incorrect or unreachable
- The `SUPublicEDKey` doesn't match the key used to sign the release
