<h1 align="center">Markdown Preview</h1>

<p align="center">
  <img src="docs/app-icon.png" width="128" alt="App icon" />
</p>

<p align="center">
  A fast, native macOS app for reading Markdown files.
</p>

<p align="center"><img alt="Platform" src="https://img.shields.io/badge/platform-macOS%2015%2B-blue" />&nbsp;<img alt="Swift" src="https://img.shields.io/badge/swift-6.0-orange" />&nbsp;<img alt="License" src="https://img.shields.io/github/license/pluk-inc/md-preview.app" />&nbsp;<img alt="Latest release" src="https://img.shields.io/github/v/release/pluk-inc/md-preview.app" /></p>

---

> Drop a `.md` on the icon (or set Markdown Preview as your default handler) and get a clean, scrollable preview with a real document outline — no Electron, no browser tab.

## Screenshots

<p align="center">
  <img src="docs/screenshot-main.png" width="820" alt="Main window with document outline sidebar" />
</p>

<p align="center">
  <em>Quick Look preview — spacebar a <code>.md</code> in Finder:</em>
</p>

<p align="center">
  <img src="docs/screenshot-quicklook.png" width="640" alt="Quick Look preview from Finder" />
</p>

## Features

- **Native rendering** — `WKWebView` pipeline backed by [swift-markdown](https://github.com/swiftlang/swift-markdown), with heading anchors and link handling.
- **Mermaid diagrams** — fenced `mermaid` code blocks render as diagrams in both the app and Quick Look previews, using a bundled renderer so previews work offline without a CDN request.
- **Document outline** — sidebar TOC that mirrors your headings; click to jump.
- **Inspector panel** — toggleable side panel with file metadata.
- **In-document search** — toolbar search field plus standard <kbd>⌘F</kbd> / <kbd>⌘G</kbd> / <kbd>⌘⇧G</kbd> for next/previous match.
- **Open With** — switch to your real editor (VS Code, Cursor, Zed, Sublime, BBEdit, Nova, CotEditor, TextMate, MacVim, Xcode, TextEdit) without leaving the preview. The list filters to apps that actually declare an editor role for Markdown, and remembers your pick.
- **Share = copy the source** — the share toolbar feeds the picker the Markdown text itself, so **Copy** writes the raw source to the clipboard (great for pasting into ChatGPT / Claude), and Mail, Messages, and Notes get the content in the body instead of a file URL.
- **Quick Look extension** — system-wide `.md` previews from Finder spacebar, Spotlight, and Mail attachments without launching the app.
- **Default handler** — offers to register itself as the default `.md` opener on first launch.

## Supported file types

`.md`, `.markdown`, `.mdown`, `.txt`
UTI: `net.daringfireball.markdown`

## Installation

Grab the latest signed and notarized DMG from the [Releases](https://github.com/pluk-inc/md-preview.app/releases) page.

## Requirements

- macOS 15 or later
- Apple Silicon or Intel

## Building from source

```sh
git clone git@github.com:pluk-inc/md-preview.app.git
cd md-preview.app
open md-preview.xcodeproj
```

Build and run the `md-preview` scheme. Swift Package Manager will resolve [Sparkle](https://github.com/sparkle-project/Sparkle) and [swift-markdown](https://github.com/swiftlang/swift-markdown) on first build.

## Project layout

```
md-preview/         Main app target (AppKit, WKWebView)
quick-look/         Quick Look extension (.appex)
scripts/            Release & rollback automation
Version.xcconfig    Marketing & build version (single source of truth)
appcast.xml         Sparkle update feed
```

## Releasing

Releases are driven by [Amore](http://amore.computer/) — it handles building, code signing, notarization, DMG creation, S3 upload, and Sparkle appcast publishing in one shot.

Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `Version.xcconfig`, then:

```sh
./scripts/release.sh
```

Use `./scripts/rollback-release.sh` to revert the appcast pointer if a release misbehaves.

## Contributing

Pull requests are welcome. For larger changes, please open an issue first to discuss what you'd like to change.

1. Fork the repo and create your branch from `main`.
2. Run the app and verify the change end-to-end (UI changes need a manual smoke test — there's no UI test suite yet).
3. Keep PRs focused; one logical change per PR.
4. Match the existing Swift style (no formatter is enforced; mirror nearby code).

## Acknowledgments

- [swift-markdown](https://github.com/swiftlang/swift-markdown) — Markdown parser (Apple, cmark-gfm-backed)
- [Mermaid](https://mermaid.js.org/) — bundled diagram renderer for `mermaid` fenced code blocks
- [Sparkle](https://sparkle-project.org) — Auto-update framework
- [Amore](http://amore.computer/) — macOS release automation (signing, notarization, DMG, hosting, appcast)

## License

[MIT](LICENSE)
