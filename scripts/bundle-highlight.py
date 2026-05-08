#!/usr/bin/env python3
"""Bundle highlight.js into self-contained vendor files.

Downloads highlight.min.js (the common-languages bundle from
@highlightjs/cdn-assets), the github + github-dark themes, and the LICENSE
from jsDelivr. Combines the two themes into a single CSS that gates dark
rules behind `prefers-color-scheme: dark`, so a single stylesheet covers
both appearances.

Run from repo root:  ./scripts/bundle-highlight.py [VERSION]
"""
import re
import subprocess
import sys
from pathlib import Path

VERSION = sys.argv[1] if len(sys.argv) > 1 else "11.10.0"
CDN = f"https://cdn.jsdelivr.net/npm/@highlightjs/cdn-assets@{VERSION}"
LICENSE_URL = f"https://raw.githubusercontent.com/highlightjs/highlight.js/{VERSION}/LICENSE"
DEST = Path("md-preview/Vendor/Highlight")


def fetch(url: str) -> bytes:
    return subprocess.run(
        ["curl", "-fsSL", url],
        check=True,
        capture_output=True,
    ).stdout


def main() -> int:
    DEST.mkdir(parents=True, exist_ok=True)

    js = fetch(f"{CDN}/highlight.min.js")
    light = fetch(f"{CDN}/styles/github.min.css").decode("utf-8").strip()
    dark = fetch(f"{CDN}/styles/github-dark.min.css").decode("utf-8").strip()
    license_text = fetch(LICENSE_URL)

    # Strip leading comment headers so the merged stylesheet stays compact.
    light = re.sub(r"^/\*![\s\S]*?\*/\s*", "", light)
    dark = re.sub(r"^/\*![\s\S]*?\*/\s*", "", dark)

    # Cancel the theme background — the host page already paints a rounded
    # `pre` background; per-token colors come through fine without it.
    combined = (
        f"{light}\n"
        f"@media (prefers-color-scheme: dark) {{ {dark} }}\n"
        ".hljs { background: transparent !important; padding: 0 !important; }\n"
    )

    (DEST / "highlight.min.js").write_bytes(js)
    (DEST / "highlight.min.css").write_text(combined, encoding="utf-8")
    (DEST / "Highlight-LICENSE.txt").write_bytes(license_text)
    # File name distinct so the synced-root-group resource copy doesn't
    # collide with md-preview/Vendor/KaTeX/VERSION in the bundle output.
    (DEST / "Highlight-VERSION").write_text(VERSION + "\n", encoding="utf-8")

    print(f"highlight.js {VERSION} bundled to {DEST}/")
    print(f"  highlight.min.js     {(DEST / 'highlight.min.js').stat().st_size:>9} bytes")
    print(f"  highlight.min.css    {(DEST / 'highlight.min.css').stat().st_size:>9} bytes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
