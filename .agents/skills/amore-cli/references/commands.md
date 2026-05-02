# Amore CLI — Complete Command Reference

Run `amore help` or `amore <command> --help` for the most current details.

## Authentication

### `amore login`
Sign in to your Amore account. Interactive — prompts for email and password.

### `amore logout`
Sign out and clear stored credentials.

### `amore register`
Create a new Amore account. Interactive.

### `amore whoami [--refresh]`
Show the currently logged-in user. Pass `--refresh` to re-fetch from the server.

## Installation

The CLI ships inside the Amore macOS app. It is not available as a standalone binary.

### `amore install`
Create symlink at `/usr/local/bin/amore`. Requires Amore.app to be installed first. May require `sudo`.

You can also run it directly without installing: `/Applications/Amore.app/Contents/MacOS/AmoreCLI install`

Or install from within the app: Command Line settings > Install.

### `amore uninstall`
Remove the `/usr/local/bin/amore` symlink.

### `amore status`
Show CLI setup status (installed path, logged-in user, etc.).

## App Setup

### `amore setup [<path>]`
Register a new app for distribution. Walks through hosting choice, S3 config, and Sparkle key generation.

**Arguments:**
- `<path>` — Path to `.app` bundle (optional, interactive if omitted)

**Hosting flags:**
- `--hosting <amore|s3>` — Skip the hosting prompt

**S3 flags** (required when `--hosting s3`):
- `--s3-bucket <name>`
- `--s3-region <region>` — e.g., `us-east-1`
- `--s3-public-url <url>` — Public base URL for downloads
- `--s3-access-key-id <key>`
- `--s3-secret-access-key <secret>`
- `--s3-endpoint <url>` — Custom endpoint (e.g., for Cloudflare R2)
- `--s3-path-prefix <prefix>` — Folder path within bucket

**Sparkle key flags:**
- `--sparkle-key <base64>` — Import an existing Ed25519 private key
- `--generate-sparkle-key` — Generate a new key without prompting

## Releasing

### `amore release [<path>]`
Build, sign, notarize, and publish a release.

**Arguments:**
- `<path>` — `.app`, `.dmg`, `.zip`, `.xcarchive`, `.xcodeproj`, or `.xcworkspace`

**Build flags:**
- `--scheme <name>` — Xcode scheme (required for projects/workspaces)
- `--product-name <name>` — Product name for Xcode archives

**Release metadata:**
- `--release-notes <text>` — Release notes
- `--beta` — Mark as beta
- `--phased-rollout` — Enable phased rollout
- `--critical` — Mark as critical update
- `--draft` — Upload but don't publish

**Packaging:**
- `--no-dmg` — Output ZIP instead of DMG (skips codesigning and notarization)
- `-o, --output <dir>` — Output directory (skips upload)

**Signing:**
- `--codesign-identity <identity>` — Developer ID identity
- `--keychain-profile <profile>` — Notarization keychain profile

**S3 credential overrides:**
- `--s3-access-key-id <key>`
- `--s3-secret-access-key <secret>`

**Examples:**
```sh
# Release from Xcode project
amore release --scheme MyApp

# Release a pre-built app
amore release ~/Desktop/MyApp.app

# Release as ZIP (no DMG, no notarization)
amore release MyApp.app --no-dmg

# Build locally without uploading
amore release --scheme MyApp --output ./build

# Beta release with notes
amore release MyApp.app --beta --release-notes "Bug fixes"

# CI/CD with explicit credentials
amore release --scheme MyApp \
  --codesign-identity "Developer ID Application: Company (TeamID)" \
  --keychain-profile "notary-profile" \
  --s3-access-key-id "$AWS_ACCESS_KEY_ID" \
  --s3-secret-access-key "$AWS_SECRET_ACCESS_KEY"
```

### `amore create-dmg <app-path>`
Create a DMG disk image without uploading.

**Arguments:**
- `<app-path>` — Path to `.app` bundle

**Options:**
- `-o, --output <path>` — Output path for the DMG
- `--open` — Open the DMG after creation
- `--codesign-identity <identity>`
- `--keychain-profile <profile>`

### `amore sign <path>`
Sign an app archive (`.dmg` or `.zip`) with your Ed25519 private key.

### `amore verify <path> <signature> <public-key>`
Verify an Ed25519 signature. Both `<signature>` and `<public-key>` are base64-encoded.

### `amore post-archive [<product-name>] [<archive-path>]`
Xcode archive post-action. Also reads `PRODUCT_NAME` and `ARCHIVE_PATH` environment variables.

## App Management

### `amore apps list`
List all registered apps.

### `amore apps delete --bundle-id <id> [--yes]`
Delete a local (S3) app. Pass `--yes` to skip confirmation.

## Release Management

### `amore releases list --bundle-id <id>`
List all releases for an app.

### `amore releases update <id> --bundle-id <id> [options]`
Update release metadata.

**Options:**
- `--published <true|false>`
- `--beta <true|false>`
- `--critical <true|false>`
- `--phased-rollout <true|false>`
- `--release-notes <text>`

### `amore releases delete <id> --bundle-id <id> [--yes]`
Delete a release.

## Product Management (Licensing)

### `amore products list --bundle-id <id>`
List licensing products for an app.

### `amore products create --bundle-id <id> --name <name> [options]`
Create a new licensing product.

**Options:**
- `--device-limit <number>` — Max devices per license (default: 1)
- `--duration-days <days>` — License duration (omit for perpetual)

### `amore products update <id> --bundle-id <id> [options]`
Update a licensing product.

**Options:**
- `--name <name>`
- `--device-limit <number>`
- `--duration-days <days>`
- `--stripe-product-id <id>`
- `--stripe-price-id <id>`

### `amore products delete <id> --bundle-id <id> [--yes]`
Delete a licensing product.

## Configuration

### `amore config show [<section>] --bundle-id <id>`
Show configuration. Sections: `release`, `s3`, `app` (shows all if omitted).

### `amore config set release <field> <value> --bundle-id <id>`
**Fields:** `codesign-identity`, `keychain-profile`, `dmg-enabled`

### `amore config set s3 <field> <value> --bundle-id <id>`
**Fields:** `bucket`, `region`, `endpoint`, `path-prefix`, `public-url`, `appcast-path`

### `amore config set app <field> <value> --bundle-id <id>`
**Fields:** `custom-domain`, `release-notes-url`, `stripe-secret-key`, `stripe-webhook-secret`, `stripe-managed-payments`

### `amore config clear --bundle-id <id>`
Clear all release configuration for an app.
