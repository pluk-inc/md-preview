# Changelog

## [0.0.15] – 2026-05-06

A proper find bar and right-to-left text support.

### Added

- **Find bar with match navigation, modes, and a burst highlight.** Searching now opens a slim bar below the toolbar with an `X of N` counter, prev/next chevrons, a Done button, and a Contains / Begins With mode toggle. Enter and Shift+Enter cycle forward and backward through matches (the original ask in [#72](https://github.com/pluk-inc/md-preview.app/issues/72)), and the current match scale-pulses with a yellow pill so it's easy to spot after a long scroll. The find pass skips scrolling when the match is already on screen, debounces keystrokes, gates Begins-With on the preceding character, and filters hidden subtrees so KaTeX MathML mirrors and Mermaid source nodes don't show up as phantom matches ([#73](https://github.com/pluk-inc/md-preview.app/pull/73)).
- **Automatic RTL text direction.** Paragraphs, list items, and headings whose first strong character is from an RTL script (Hebrew, Arabic, Syriac, etc.) now render with `dir="rtl"` and right alignment. Detection looks through inline markup (so `**שלום**` works), skips neutral characters like parentheses and punctuation, preserves any existing `dir` attribute, and leaves LTR-only documents unchanged ([#67](https://github.com/pluk-inc/md-preview.app/pull/67)).

### Contributors

Thanks to the external contributor who shipped in this release:

- [@manemajef](https://github.com/manemajef) — automatic RTL text direction support ([#67](https://github.com/pluk-inc/md-preview.app/pull/67))

## [0.0.14] – 2026-05-06

Quick Look now renders relative images.

### Added

- **Relative images render in Quick Look previews.** When a Markdown file references sibling assets like `![](images/local.png)`, the Quick Look extension now inlines each readable sibling as a `cid:` attachment on the preview reply and rewrites the `<img src>` to match, so local images appear in Finder/Spotlight previews instead of as broken-image glyphs. The extension gained a read-only `temporary-exception.files.absolute-path.read-only` entitlement so the sandboxed preview process can read sibling files (the main app already handles this through its `md-asset://` scheme). Per-image and cumulative byte budgets cap pathological folders; absolute URLs, fragment refs, host-absolute paths, and unreadable files pass through untouched ([#68](https://github.com/pluk-inc/md-preview.app/pull/68)).

### Contributors

Thanks to the external contributor who shipped in this release:

- [@DivineDominion](https://github.com/DivineDominion) — relative images in Quick Look previews ([#68](https://github.com/pluk-inc/md-preview.app/pull/68))

## [0.0.13] – 2026-05-05

Native printing, plus two rendering fixes.

### Added

- **Print the rendered Markdown.** File → Print (⌘P) now prints the previewed document through WKWebView with horizontal fit pagination, instead of falling through to AppKit's generic `print:` and printing the sidebar and window chrome. The app gained the `com.apple.security.print` entitlement so this works in the sandbox.

### Fixed

- **GFM task lists render inline without a duplicate bullet.** Task list items were drawing both a list marker and a checkbox with the label wrapping to a new line below. Task `<li>`s and their checkboxes are now tagged with GitHub's `task-list-item` / `task-list-item-checkbox` class names, so CSS suppresses the marker and the first paragraph stays inline next to the checkbox ([#63](https://github.com/pluk-inc/md-preview.app/issues/63)).
- **No placeholder content on launch.** Removed the leftover "WKWebView pipeline is live" sample that the split view rendered at startup, so the app opens with an empty preview area until you load a document.

## [0.0.12] – 2026-05-05

Code highlighting, richer Markdown heading and footnote rendering, and README sponsor updates.

### Added

- **Code blocks now use Shiki syntax highlighting.** Fenced code blocks render with bundled Shiki highlighting in both the app and Quick Look, so previews show language-aware colors without needing network access.

### Fixed

- **Footnotes now render correctly.** Markdown footnote definitions and references are collected, linked, and rendered as a proper footnotes section instead of appearing as plain paragraph content.
- **Inline markup works inside headings.** Emphasis, links, code spans, and other inline Markdown now render correctly inside heading text while keeping generated heading anchors stable.

## [0.0.11] – 2026-05-04

Homebrew install path and stronger default-handler claims for Markdown files.

### Added

- **Install via Homebrew.** `brew install --cask pluk-inc/tap/markdown-preview` is now the primary install method; the DMG remains as a fallback. The release script auto-bumps the [pluk-inc/homebrew-tap](https://github.com/pluk-inc/homebrew-tap) cask (version + sha256) after each successful `amore release`, so brew users pick up new versions on the same cadence as direct downloads.

### Fixed

- **Markdown Preview now wins as the default `.md` handler on more setups.** `LSHandlerRank` for the standard markdown UTI was promoted from `Default` to `Owner`, so LaunchServices prefers Markdown Preview over apps that only assert a weaker claim. Users who previously had to set "Always Open With" by hand should pick the app up automatically after a fresh install.
- **Long-tail markdown extensions are now claimed uncontested.** `.mdown`, `.mkd`, `.mkdn`, `.mdwn`, `.mdtxt`, and `.mdtext` are exported under app-private UTIs (`doc.md-preview.*`) that conform to `net.daringfireball.markdown`. Because no other app declares UTIs in that namespace, LaunchServices has no competing candidate for these files and Markdown Preview opens them without requiring user intervention.

## [0.0.10] – 2026-05-04

LaTeX math rendering, broader Markdown file-format support, and a rendering fix for inline HTML in body text and code.

### Added

- **LaTeX math now renders via KaTeX.** Inline math (`$…$`, `\(…\)`) and display math (`$$…$$`, `\[…\]`) are typeset on load in both the app and the Quick Look extension. KaTeX ships inside the bundle, so previews work offline.
- **More Markdown file types open natively.** Added `.mkd`, `.mkdn`, `.mdwn`, `.mdtxt`, `.mdtext`, and `.rmd` alongside the existing `.md` / `.markdown` / `.mdown` / `.txt`. Quick Look and the Open With list pick the app up for these extensions too.

### Fixed

- **Math extraction skips code spans and fences.** Dollar signs and `\(…\)` sequences inside backticks or fenced code blocks are no longer mistaken for math, so snippets like `` `$PATH` `` and code samples render verbatim instead of being eaten by the math pass.
- **HTML in body text and code is now properly escaped.** `a < b`, `Tom & Jerry`, `` `<div>` ``, and fenced code containing `<`, `>`, or `&` previously rendered mangled or vanished entirely because swift-markdown's default `HTMLFormatter` doesn't escape those characters in text or code. A new `EscapingHTMLFormatter` walker handles escaping while still passing raw HTML blocks through verbatim per CommonMark.

### Contributors

Thanks to the external contributors who shipped in this release:

- [@dppeak](https://github.com/dppeak) — broader Markdown file-format support ([#31](https://github.com/pluk-inc/md-preview.app/pull/31))
- [@yaksher](https://github.com/yaksher) — reported the HTML-escape bug fixed in [#35](https://github.com/pluk-inc/md-preview.app/pull/35) ([#33](https://github.com/pluk-inc/md-preview.app/issues/33))

## [0.0.9] – 2026-05-03

Mermaid diagram rendering in the app and Quick Look.

- **Fenced `mermaid` code blocks now render as diagrams.** The Markdown pipeline detects `mermaid` fences, swaps them for diagram containers, and runs the Mermaid renderer on load — flowcharts, sequence diagrams, class diagrams, and the rest show up inline instead of as raw code.
- **Renderer is bundled, so previews work offline.** The Mermaid script ships inside the app bundle and is shared with the Quick Look extension; no CDN request is made when opening a document.
- **Diagrams follow the system appearance.** Mermaid initializes with the dark theme when the system is in dark mode and the default theme otherwise, and uses the SF system font so labels match the surrounding text.

## [0.0.8] – 2026-05-03

Tabbed Inspector with native segmented picker.

- **Inspector now has Document and Properties tabs.** A native segmented picker with SF Symbol icons (doc / info) splits the panel into a Document tab for file and content stats and a Properties tab for YAML frontmatter, instead of stacking everything in one scrolling list.
- **Empty Properties tab shows a placeholder.** Documents without frontmatter now display "No YAML frontmatter" filling the available space, so the tab doesn't collapse to nothing.
- **Picker matches Apple's pill-style segmented look on macOS 26 Tahoe.** Uses `.controlSize(.large)` plus `.buttonSizing(.flexible)` on Tahoe and falls back to `.fixedSize()` on macOS 15 Sequoia.

## [0.0.7] – 2026-05-03

YAML frontmatter rendering fix and Inspector metadata.

- **YAML frontmatter no longer collapses into a giant heading.** The CommonMark renderer was treating the closing `---` of a frontmatter block as a setext heading underline, turning `title:` / `date:` / `tags:` into one oversized H2 at the top of the document. The block is now stripped before parsing and the preview matches what GitHub, Obsidian, and VS Code show.
- **Frontmatter shows up in the Inspector.** A new **Properties** section at the top of the Inspector lists each key/value pair from the document's frontmatter, so the metadata is one click away even though it's hidden from the rendered preview. The Quick Look extension hides it too.
- **Word, line, and heading counts now reflect body content.** The Inspector's stats no longer include the frontmatter block in their totals.

## [0.0.6] – 2026-05-02

Toolbar, banner, and table-of-contents polish.

- **Search field collapses to a magnifying-glass button in narrow windows.** When the toolbar is too tight to fit the expanded search field, it now folds into an icon-only button matching the rest of the toolbar instead of being clipped.
- **Open With toolbar item shows the resolved editor.** When a default Markdown editor is set, the toolbar item now reads "Open in <Editor>" as both label and tooltip, and the menu lists apps by their Finder display name without the `.app` suffix. The chosen editor's location is also remembered alongside its bundle ID, so launches still resolve when the bundle ID is unavailable.
- **Folder-access banner no longer clips text on macOS 15.** The banner now advertises a fixed height to the titlebar accessory so descenders in the message label aren't cut off, and the redundant top/bottom separators are hidden on macOS 15 (where AppKit already draws system ones).
- **Folder-access banner stays until access is granted.** Removed the dismiss button so the prompt no longer disappears when accidentally clicked — it now goes away only after you grant read access to the folder.
- **TOC clicks scroll headings below the toolbar.** Jumping to a heading from the sidebar now accounts for the toolbar height plus a small breathing margin, so the target heading lands in view instead of behind the toolbar.
- **Share toolbar button is the right size.** The share item no longer renders an oversized icon next to the other toolbar buttons.

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
