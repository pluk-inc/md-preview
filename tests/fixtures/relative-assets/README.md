# Quick Look relative-asset fixture

Manual verification fixture for the Quick Look extension's relative-link
support. Not consumed by any automated build target — kept in the repo so
contributors can reproduce the QL test described in the PR.

## How to use

```bash
xcodebuild -project md-preview.xcodeproj -scheme md-preview \
    -configuration Debug build
qlmanage -r && qlmanage -r cache
open -R tests/fixtures/relative-assets/post.md   # reveal in Finder
# then press space on post.md
```

Expectations:

- `images/local.png` renders.
- `images dir/two words.png` renders (URL-decoded path).
- The remote https image renders (network entitlement already granted).
- `images/missing.png` shows the broken-image glyph; the preview does not
  crash.

If sandbox denials show up in Console.app filtered by `quick-look`, the
extension's read access to siblings is being refused before the
`cid:`/`QLPreviewReply.attachments` rewrite can read the files.
