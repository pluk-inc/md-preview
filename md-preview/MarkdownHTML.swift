//
//  MarkdownHTML.swift
//  md-preview
//

import Foundation
import Markdown

enum MarkdownHTML {
    static func makeHTML(from markdown: String,
                         allowsScroll: Bool = false,
                         assetBaseHref: String? = nil) -> String {
        let renderedBody = renderMermaidBlocks(in: HTMLFormatter.format(MarkdownFrontmatter.split(markdown).body))
        let body = injectHeadingIDs(in: renderedBody.html)
        let scrollOverride = allowsScroll ? """
        <style>
        html, body { overflow: auto !important; }
        ::-webkit-scrollbar { display: initial !important; width: auto !important; height: auto !important; }
        </style>
        """ : ""
        let baseTag = assetBaseHref.map { "<base href=\"\($0)\">" } ?? ""
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        \(baseTag)
        <style>\(stylesheet)</style>
        \(scrollOverride)
        \(renderedBody.containsMermaid ? mermaidScript : "")
        </head>
        <body>
        <article class="markdown-body">
        \(body)
        </article>
        </body>
        </html>
        """
    }

    private static let headingTagRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: "<h([1-6])>")
    }()

    private static func injectHeadingIDs(in html: String) -> String {
        let nsHtml = html as NSString
        let matches = headingTagRegex.matches(
            in: html,
            range: NSRange(location: 0, length: nsHtml.length)
        )
        guard !matches.isEmpty else { return html }

        var result = ""
        result.reserveCapacity(html.count + matches.count * 24)
        var cursor = 0

        for (index, match) in matches.enumerated() {
            let level = nsHtml.substring(with: match.range(at: 1))
            let prefix = nsHtml.substring(with: NSRange(
                location: cursor,
                length: match.range.location - cursor
            ))
            result += prefix
            result += "<h\(level) id=\"md-heading-\(index)\">"
            cursor = match.range.location + match.range.length
        }
        result += nsHtml.substring(from: cursor)
        return result
    }
    private struct MermaidRenderResult {
        let html: String
        let containsMermaid: Bool
    }

    private static let mermaidRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(
            pattern: #"<pre><code class="language-mermaid">([\s\S]*?)</code></pre>"#
        )
    }()

    private static func renderMermaidBlocks(in html: String) -> MermaidRenderResult {
        let nsHtml = html as NSString
        let matches = mermaidRegex.matches(
            in: html,
            range: NSRange(location: 0, length: nsHtml.length)
        )
        guard !matches.isEmpty else {
            return MermaidRenderResult(html: html, containsMermaid: false)
        }

        var result = ""
        result.reserveCapacity(html.count)
        var cursor = 0

        for match in matches {
            result += nsHtml.substring(with: NSRange(
                location: cursor,
                length: match.range.location - cursor
            ))
            let diagram = nsHtml.substring(with: match.range(at: 1))
            result += """
            <div class="mermaid" role="img" aria-label="Mermaid diagram">
            \(diagram)
            </div>
            """
            cursor = match.range.location + match.range.length
        }

        result += nsHtml.substring(from: cursor)
        return MermaidRenderResult(html: result, containsMermaid: true)
    }

    private static var mermaidScript: String {
        guard let script = bundledMermaidScript else {
            return """
            <script>
            window.addEventListener('load', () => {
                document.querySelectorAll('.mermaid').forEach((node) => {
                    node.classList.add('mermaid-error');
                    node.textContent = 'Mermaid renderer is unavailable.\\n\\n' + node.textContent;
                });
            });
            </script>
            """
        }

        return """
        <script>
        \(script)

        window.addEventListener('load', async () => {
            const darkMode = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
            try {
                mermaid.initialize({
                    startOnLoad: false,
                    theme: darkMode ? 'dark' : 'default',
                    securityLevel: 'strict',
                    fontFamily: '-apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, sans-serif'
                });
                await mermaid.run({ querySelector: '.mermaid' });
            } catch (error) {
                document.querySelectorAll('.mermaid').forEach((node) => {
                    node.classList.add('mermaid-error');
                });
                console.error('Mermaid rendering failed', error);
            }
        });
        </script>
        """
    }

    private static var bundledMermaidScript: String? {
        let bundles = [Bundle.main, Bundle(for: MarkdownHTMLBundleToken.self)]
        for bundle in bundles {
            let urls = [
                bundle.url(
                    forResource: "mermaid.min",
                    withExtension: "js",
                    subdirectory: "Vendor/Mermaid"
                ),
                bundle.url(forResource: "mermaid.min", withExtension: "js"),
            ]
            for url in urls.compactMap({ $0 }) {
                guard let script = try? String(contentsOf: url, encoding: .utf8) else { continue }
                return script.replacingOccurrences(of: "</script", with: "<\\/script")
            }
        }
        return nil
    }

    private final class MarkdownHTMLBundleToken {}


    // Mirrors MarkdownUI's Theme.docC. Top-only margins (bottom: 0), Apple SF
    // palette (text #1d1d1f / #f5f5f7, link #0066cc / #2997ff, grid #d2d2d7 /
    // #424245, code bg #f5f5f7 / #2A2828, aside bg #f5f5f7 / #323232), 15px continuous container
    // radius, horizontal-only table borders.
    private static let stylesheet = """
    :root {
        color-scheme: light dark;
        --text: #1d1d1f;
        --secondary: #6e6e73;
        --link: #0066cc;
        --aside-bg: #f5f5f7;
        --aside-border: #696969;
        --code-bg: #f5f5f7;
        --grid: #d2d2d7;
    }
    @media (prefers-color-scheme: dark) {
        :root {
            --text: #f5f5f7;
            --secondary: #86868b;
            --link: #2997ff;
            --aside-bg: #323232;
            --aside-border: #9a9a9e;
            --code-bg: #2A2828;
            --grid: #424245;
        }
    }

    * { box-sizing: border-box; }
    mark.md-search-highlight {
        background: #ffd84d;
        color: #1d1d1f;
        -webkit-box-decoration-break: clone;
    }
    mark.md-search-highlight-current {
        background: #ffbf00;
    }
    html, body {
        margin: 0;
        padding: 0;
        overflow: hidden;
    }
    ::-webkit-scrollbar {
        display: none;
        width: 0;
        height: 0;
    }
    body {
        font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, sans-serif;
        font-size: 15px;
        line-height: 1.52;
        color: var(--text);
        background: transparent;
        padding: 32px 40px 48px;
        -webkit-font-smoothing: antialiased;
    }

    article.markdown-body > *:first-child { margin-top: 0 !important; }

    p {
        margin: 0.8em 0 0;
    }

    h1, h2, h3, h4, h5, h6 {
        font-weight: 600;
        line-height: 1.18;
        margin: 1.6em 0 0;
    }
    h1 { font-size: 2em; margin-top: 0.8em; }
    h2 { font-size: 1.88em; line-height: 1.06; }
    h3 { font-size: 1.65em; line-height: 1.07; }
    h4 { font-size: 1.41em; line-height: 1.08; }
    h5 { font-size: 1.29em; line-height: 1.09; }
    h6 { font-size: 1em; line-height: 1.24; }

    a { color: var(--link); text-decoration: none; }
    a:hover { text-decoration: underline; }

    code {
        font-family: ui-monospace, "SF Mono", Menlo, monospace;
        font-size: 0.88em;
        padding: 0.18em 0.42em;
        background: var(--code-bg);
        border-radius: 6px;
    }
    pre {
        margin: 0.8em 0 0;
        padding: 10px 14px;
        background: var(--code-bg);
        border-radius: 15px;
        overflow-x: auto;
        line-height: 1.45;
    }
    pre code {
        padding: 0;
        background: transparent;
        font-size: 0.88em;
    }
    .mermaid {
        margin: 1.6em 0 0;
        padding: 16px;
        background: var(--code-bg);
        border-radius: 15px;
        overflow-x: auto;
        text-align: center;
    }
    .mermaid svg {
        max-width: 100%;
        height: auto;
    }
    .mermaid-error {
        text-align: left;
        white-space: pre-wrap;
        font-family: ui-monospace, "SF Mono", Menlo, monospace;
        font-size: 0.88em;
    }

    blockquote {
        margin: 1.6em 0 0;
        padding: 14px 16px;
        background: var(--aside-bg);
        border-radius: 15px;
        color: var(--text);
    }
    blockquote > *:first-child { margin-top: 0; }

    ul, ol { margin: 0.8em 0 0; padding-left: 1.6em; }
    li { margin-top: 0.4em; }
    li:first-child { margin-top: 0.8em; }
    li > ul, li > ol { margin-top: 0.4em; }
    li > p:first-child { margin-top: 0; }

    table {
        margin: 1.6em 0 0;
        border-collapse: collapse;
        display: block;
        overflow-x: auto;
        max-width: 100%;
    }
    th, td {
        padding: 9px 10px;
        border-top: 1px solid var(--grid);
        border-bottom: 1px solid var(--grid);
        text-align: left;
    }
    th { font-weight: 600; }

    hr {
        border: 0;
        height: 1px;
        background: var(--grid);
        margin: 2.35em 0;
    }

    img {
        display: block;
        max-width: 100%;
        height: auto;
        margin: 1.6em auto;
        border-radius: 10px;
    }
    p img {
        display: inline-block;
        vertical-align: middle;
        margin: 0 0.35em 0.35em 0;
    }
    p > img:only-child {
        display: block;
        margin: 1.6em auto;
    }

    strong { font-weight: 600; }
    em { font-style: italic; }

    """
}
