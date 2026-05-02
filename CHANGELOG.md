# Changelog

## [0.0.5] – 2026-05-02

Small fullscreen polish for the sidebar.

- **Sidebar title sits correctly in fullscreen.** The document title at the top of the table-of-contents pane no longer slides under the toolbar when the window enters fullscreen — it now anchors to the safe-area inset and stays put in both windowed and fullscreen modes.

## [0.0.4] – 2026-05-02

Relative images and links in Markdown files now render in the sandboxed app.

- **Render relative local assets via a folder-access banner.** When a document references images or files alongside it, Markdown Preview now shows an in-window banner offering to grant read access to the parent folder. Once granted, the access is remembered across launches and assets load through a dedicated `md-asset://` scheme so they appear inline in the preview.
- **Stable DMG filename for GitHub releases.** The DMG attached to each GitHub release is now `Markdown-Preview.dmg` without a version suffix, so download links stay valid across versions.

## [0.0.3] – 2026-05-02

Better Markdown rendering and a tidier **Open With** menu.

- **Switched the Markdown engine to swift-markdown (cmark-gfm).** Rendering is now CommonMark- and GitHub-Flavored-Markdown-compliant, so tables, task lists, strikethrough, and autolinks render the way you'd expect on GitHub.
- **Fixed the Open With list.** No more duplicate Markdown Preview entries from old build copies, and unrelated apps that only claim a generic plain-text association no longer show up — only apps that actually edit Markdown are listed.

## [0.0.2] – 2026-05-01

Compatibility release: Markdown Preview now runs on macOS 15 Sequoia in addition to macOS 26 Tahoe.

- **Lowered the minimum macOS version to 15.0 (Sequoia).** Previously required macOS 26 Tahoe.
- **Replaced the app icon with an Icon Composer `.icon` bundle.** Fixes the icon appearing oversized on Sequoia — the system now applies its own mask and the standard safe-area inset.

## [0.0.1] – 2026-04-30

First public build of Markdown Preview — a fast, native macOS reader for `.md` files.

### Highlights

- Native WKWebView rendering with heading anchors and external link handling
- Sidebar table of contents that mirrors document headings (click to jump)
- Toggleable inspector panel with file metadata
- In-document search via the toolbar field plus standard `⌘F` / `⌘G` / `⌘⇧G`
- Open With menu that filters to apps declaring an editor role for Markdown and remembers your pick
- Share menu that copies the Markdown source itself, so Copy / Mail / Notes / Messages get the content instead of a file URL
- Quick Look extension for system-wide `.md` previews from Finder, Spotlight, and Mail
- Offer to register as the default `.md` handler on first launch
- Supports `.md`, `.markdown`, `.mdown`, and `.txt`
