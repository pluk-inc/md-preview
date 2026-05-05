//
//  MarkdownHTML.swift
//  md-preview
//

import Foundation
import Markdown

enum MarkdownHTML {
    struct RenderedHTML {
        let html: String
        let containsMath: Bool
        let containsMermaid: Bool
        let containsHighlightedCode: Bool
    }

    static func makeHTML(from markdown: String,
                         allowsScroll: Bool = false,
                         assetBaseHref: String? = nil) -> String {
        render(markdown: markdown,
               allowsScroll: allowsScroll,
               assetBaseHref: assetBaseHref).html
    }

    static func render(markdown: String,
                       allowsScroll: Bool = false,
                       assetBaseHref: String? = nil) -> RenderedHTML {
        let body = MarkdownFrontmatter.split(markdown).body
        let footnotes = extractFootnotes(from: body)
        let math = extractMath(from: footnotes.markdown)
        let formatted = EscapingHTMLFormatter.format(math.processedMarkdown)
        let mermaidResult = renderMermaidBlocks(in: formatted)
        let shikiResult = detectHighlightableCode(in: mermaidResult.html)
        let mathResult = renderMathBlocks(in: shikiResult.html, with: math)
        let footnoteReferenceHTML = renderFootnoteReferences(in: mathResult.html, with: footnotes)
        let footnoteDefinitions = renderFootnoteDefinitions(footnotes)
        let bodyHTML = injectHeadingIDs(in: footnoteReferenceHTML + footnoteDefinitions.html)
        let scrollOverride = allowsScroll ? """
        <style>
        html, body { overflow: auto !important; }
        ::-webkit-scrollbar { display: initial !important; width: auto !important; height: auto !important; }
        </style>
        """ : ""
        let baseTag = assetBaseHref.map { "<base href=\"\($0)\">" } ?? ""
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        \(baseTag)
        <style>\(stylesheet)</style>
        \(scrollOverride)
        \(mathResult.containsMath || footnoteDefinitions.containsMath ? katexHead : "")
        \(mermaidResult.containsMermaid || footnoteDefinitions.containsMermaid ? mermaidScript : "")
        \(shikiResult.containsHighlightedCode || footnoteDefinitions.containsHighlightedCode ? shikiScript : "")
        \(codeCopyScript)
        </head>
        <body>
        <article class="markdown-body">
        \(bodyHTML)
        </article>
        </body>
        </html>
        """
        return RenderedHTML(
            html: html,
            containsMath: mathResult.containsMath || footnoteDefinitions.containsMath,
            containsMermaid: mermaidResult.containsMermaid || footnoteDefinitions.containsMermaid,
            containsHighlightedCode: shikiResult.containsHighlightedCode || footnoteDefinitions.containsHighlightedCode
        )
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

    // MARK: - Footnotes

    private struct FootnoteExtraction {
        let markdown: String
        let definitions: [FootnoteDefinition]
        let references: [FootnoteReference]
    }

    private struct FootnoteDefinition {
        let key: String
        let label: String
        let content: String
        let number: Int
    }

    private struct FootnoteReference {
        let token: String
        let number: Int
        let ordinal: Int
    }

    private struct FootnoteDefinitionRenderResult {
        let html: String
        let containsMath: Bool
        let containsMermaid: Bool
        let containsHighlightedCode: Bool
    }

    private static let footnoteDefinitionRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: #"^[ \t]{0,3}\[\^([^\]\n]+)\]:[ \t]*(.*)$"#)
    }()

    private static let footnoteReferenceRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: #"\[\^([^\]\n]+)\]"#)
    }()

    private static func extractFootnotes(from markdown: String) -> FootnoteExtraction {
        let split = splitFootnoteDefinitions(from: markdown)
        var protected: [String] = []

        let afterFences = replaceFullMatches(of: codeFenceRegex, in: split.markdown) { full in
            protected.append(full)
            return "MdPreviewFootnoteProtect\(protected.count - 1)Token"
        }
        let afterInlineCode = replaceFullMatches(of: inlineCodeRegex, in: afterFences) { full in
            protected.append(full)
            return "MdPreviewFootnoteProtect\(protected.count - 1)Token"
        }

        var orderedDefinitions: [FootnoteDefinition] = []
        var referenceOrdinalsByNumber: [Int: Int] = [:]
        var references: [FootnoteReference] = []

        let replacedReferences = replaceFootnoteReferenceMatches(in: afterInlineCode) { label, full in
            let key = normalizeFootnoteKey(label)
            guard let stored = split.definitions[key] else { return full }

            let definition: FootnoteDefinition
            if let existing = orderedDefinitions.first(where: { $0.key == key }) {
                definition = existing
            } else {
                definition = FootnoteDefinition(
                    key: key,
                    label: stored.label,
                    content: stored.content,
                    number: orderedDefinitions.count + 1
                )
                orderedDefinitions.append(definition)
            }

            let ordinal = (referenceOrdinalsByNumber[definition.number] ?? 0) + 1
            referenceOrdinalsByNumber[definition.number] = ordinal
            let token = "MdPreviewFootnoteRef\(references.count)Token"
            references.append(FootnoteReference(token: token, number: definition.number, ordinal: ordinal))
            return token
        }

        var restored = replacedReferences
        for (i, original) in protected.enumerated() {
            restored = restored.replacingOccurrences(
                of: "MdPreviewFootnoteProtect\(i)Token",
                with: original
            )
        }

        return FootnoteExtraction(
            markdown: restored,
            definitions: orderedDefinitions,
            references: references
        )
    }

    private static func splitFootnoteDefinitions(from markdown: String) -> (
        markdown: String,
        definitions: [String: (label: String, content: String)]
    ) {
        let lines = markdown.components(separatedBy: "\n")
        var output: [String] = []
        var definitions: [String: (label: String, content: String)] = [:]
        var index = 0

        while index < lines.count {
            let line = lines[index]
            if let match = firstMatch(of: footnoteDefinitionRegex, in: line) {
                let nsLine = line as NSString
                let label = nsLine.substring(with: match.range(at: 1))
                var contentLines = [nsLine.substring(with: match.range(at: 2))]
                index += 1

                while index < lines.count {
                    let continuation = lines[index]
                    if continuation.trimmingCharacters(in: .whitespaces).isEmpty {
                        if index + 1 < lines.count, isIndentedFootnoteContinuation(lines[index + 1]) {
                            contentLines.append("")
                            index += 1
                            continue
                        }
                        break
                    }
                    guard isIndentedFootnoteContinuation(continuation) else { break }
                    contentLines.append(stripFootnoteContinuationIndent(from: continuation))
                    index += 1
                }

                definitions[normalizeFootnoteKey(label)] = (
                    label: label,
                    content: contentLines.joined(separator: "\n")
                )
            } else {
                output.append(line)
                index += 1
            }
        }

        return (output.joined(separator: "\n"), definitions)
    }

    private static func firstMatch(of regex: NSRegularExpression,
                                   in source: String) -> NSTextCheckingResult? {
        let nsSource = source as NSString
        return regex.firstMatch(
            in: source,
            range: NSRange(location: 0, length: nsSource.length)
        )
    }

    private static func isIndentedFootnoteContinuation(_ line: String) -> Bool {
        if line.hasPrefix("\t") { return true }
        return line.count >= 4 && line.prefix(4).allSatisfy { $0 == " " }
    }

    private static func stripFootnoteContinuationIndent(from line: String) -> String {
        if line.hasPrefix("\t") {
            return String(line.dropFirst())
        }
        if line.count >= 4 && line.prefix(4).allSatisfy({ $0 == " " }) {
            return String(line.dropFirst(4))
        }
        return line
    }

    private static func normalizeFootnoteKey(_ label: String) -> String {
        label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func replaceFootnoteReferenceMatches(in source: String,
                                                        transform: (String, String) -> String) -> String {
        let nsSource = source as NSString
        let matches = footnoteReferenceRegex.matches(
            in: source,
            range: NSRange(location: 0, length: nsSource.length)
        )
        guard !matches.isEmpty else { return source }

        var result = ""
        result.reserveCapacity(source.count)
        var cursor = 0
        for match in matches {
            result += nsSource.substring(with: NSRange(
                location: cursor,
                length: match.range.location - cursor
            ))
            let full = nsSource.substring(with: match.range)
            let label = nsSource.substring(with: match.range(at: 1))
            result += transform(label, full)
            cursor = match.range.location + match.range.length
        }
        result += nsSource.substring(from: cursor)
        return result
    }

    private static func renderFootnoteReferences(in html: String,
                                                 with footnotes: FootnoteExtraction) -> String {
        guard !footnotes.references.isEmpty else { return html }
        var rendered = html
        for reference in footnotes.references {
            let refID = footnoteReferenceID(number: reference.number, ordinal: reference.ordinal)
            let footnoteID = footnoteDefinitionID(number: reference.number)
            let replacement = """
            <sup class="footnote-ref"><a id="\(refID)" href="#\(footnoteID)" aria-label="Footnote \(reference.number)">\(reference.number)</a></sup>
            """
            rendered = rendered.replacingOccurrences(of: reference.token, with: replacement)
        }
        return rendered
    }

    private static func renderFootnoteDefinitions(_ footnotes: FootnoteExtraction) -> FootnoteDefinitionRenderResult {
        guard !footnotes.definitions.isEmpty else {
            return FootnoteDefinitionRenderResult(
                html: "",
                containsMath: false,
                containsMermaid: false,
                containsHighlightedCode: false
            )
        }

        var containsMath = false
        var containsMermaid = false
        var containsHighlightedCode = false
        let referencesByNumber = Dictionary(grouping: footnotes.references, by: { $0.number })
        let items = footnotes.definitions.map { definition -> String in
            let renderedContent = renderFootnoteDefinitionContent(definition.content)
            containsMath = containsMath || renderedContent.containsMath
            containsMermaid = containsMermaid || renderedContent.containsMermaid
            containsHighlightedCode = containsHighlightedCode || renderedContent.containsHighlightedCode
            let backrefs = (referencesByNumber[definition.number] ?? []).map { reference in
                """
                <a href="#\(footnoteReferenceID(number: reference.number, ordinal: reference.ordinal))" class="footnote-backref" aria-label="Back to reference \(reference.number)">&#8617;</a>
                """
            }.joined(separator: " ")
            let contentHTML = appendFootnoteBackrefs(backrefs, to: renderedContent.html)

            return """
            <li id="\(footnoteDefinitionID(number: definition.number))">
            \(contentHTML)
            </li>
            """
        }.joined(separator: "\n")

        return FootnoteDefinitionRenderResult(
            html: """

            <section class="footnotes" role="doc-endnotes">
            <hr />
            <ol>
            \(items)
            </ol>
            </section>
            """,
            containsMath: containsMath,
            containsMermaid: containsMermaid,
            containsHighlightedCode: containsHighlightedCode
        )
    }

    private static func appendFootnoteBackrefs(_ backrefs: String, to html: String) -> String {
        guard !backrefs.isEmpty else { return html }
        let inlineBackrefs = "<span class=\"footnote-backrefs\">\(backrefs)</span>"
        if let range = html.range(of: "</p>", options: .backwards) {
            var updated = html
            updated.replaceSubrange(range, with: " \(inlineBackrefs)</p>")
            return updated
        }
        return html + inlineBackrefs
    }

    private static func renderFootnoteDefinitionContent(_ markdown: String) -> FootnoteDefinitionRenderResult {
        let math = extractMath(from: markdown.trimmingCharacters(in: .whitespacesAndNewlines))
        let formatted = EscapingHTMLFormatter.format(math.processedMarkdown)
        let mermaidResult = renderMermaidBlocks(in: formatted)
        let shikiResult = detectHighlightableCode(in: mermaidResult.html)
        let mathResult = renderMathBlocks(in: shikiResult.html, with: math)
        return FootnoteDefinitionRenderResult(
            html: mathResult.html,
            containsMath: mathResult.containsMath,
            containsMermaid: mermaidResult.containsMermaid,
            containsHighlightedCode: shikiResult.containsHighlightedCode
        )
    }

    private static func footnoteDefinitionID(number: Int) -> String {
        "fn-\(number)"
    }

    private static func footnoteReferenceID(number: Int, ordinal: Int) -> String {
        ordinal == 1 ? "fnref-\(number)" : "fnref-\(number)-\(ordinal)"
    }

    // MARK: - Math (KaTeX)

    private struct MathExtraction {
        let processedMarkdown: String
        let blocks: [String]
        let inlines: [String]
    }

    private struct MathRenderResult {
        let html: String
        let containsMath: Bool
    }

    private static let blockMathRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: #"\$\$([\s\S]+?)\$\$"#)
    }()

    // Reject leading `\$` (escaped) and require non-whitespace adjacent to
    // delimiters so prose like "$5 and $10" doesn't match.
    private static let inlineMathRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: #"(?<!\\)\$(?=\S)([^\$\n]+?)(?<=\S)\$"#)
    }()

    // Fenced code block. Group 1 = backtick run, group 2 = info string, group 3 = body.
    private static let codeFenceRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(
            pattern: #"(?m)^(`{3,})[ \t]*([^\n`]*)\n([\s\S]*?)\n\1[ \t]*$"#
        )
    }()

    // Inline code span: matched-length backtick runs that are not adjacent to other
    // backticks. Mirrors CommonMark so spans like `` ` ```math ` `` (single-backtick
    // delimiters around three inner backticks) tokenize correctly.
    private static let inlineCodeRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: #"(?<!`)(`+)(?!`)([^\n]*?)(?<!`)\1(?!`)"#)
    }()

    // First alternative captures kind+index for a paragraph-wrapped block token
    // (the common case after swift-markdown wraps the standalone token); the
    // second captures a bare token. The wrapper is stripped in either case for
    // block kind to keep the resulting `<div>` out of an enclosing `<p>`.
    private static let mathTokenRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(
            pattern: #"<p>MdPreviewMath(Block|Inline)(\d+)Token</p>|MdPreviewMath(Block|Inline)(\d+)Token"#
        )
    }()

    private static func extractMath(from markdown: String) -> MathExtraction {
        var blocks: [String] = []
        var inlines: [String] = []
        var protected: [String] = []

        let nsMarkdown = markdown as NSString
        let fenceMatches = codeFenceRegex.matches(
            in: markdown,
            range: NSRange(location: 0, length: nsMarkdown.length)
        )
        var afterFences = ""
        afterFences.reserveCapacity(markdown.count)
        var fenceCursor = 0
        for match in fenceMatches {
            afterFences += nsMarkdown.substring(with: NSRange(
                location: fenceCursor,
                length: match.range.location - fenceCursor
            ))
            let info = nsMarkdown
                .substring(with: match.range(at: 2))
                .trimmingCharacters(in: .whitespaces)
                .lowercased()
            if info == "math" {
                let body = nsMarkdown.substring(with: match.range(at: 3))
                blocks.append(body)
                // Surround with blank lines so swift-markdown wraps the standalone
                // token in its own <p>, which mathTokenRegex then strips.
                afterFences += "\n\nMdPreviewMathBlock\(blocks.count - 1)Token\n\n"
            } else {
                protected.append(nsMarkdown.substring(with: match.range))
                afterFences += "MdPreviewProtect\(protected.count - 1)Token"
            }
            fenceCursor = match.range.location + match.range.length
        }
        afterFences += nsMarkdown.substring(from: fenceCursor)

        // Inline code spans next, so $..$ inside `` `$x$` `` is not extracted.
        let afterInlineCode = replaceFullMatches(of: inlineCodeRegex, in: afterFences) { full in
            protected.append(full)
            return "MdPreviewProtect\(protected.count - 1)Token"
        }

        let afterBlockMath = replaceMatches(of: blockMathRegex, in: afterInlineCode) { capture in
            defer { blocks.append(capture) }
            return "MdPreviewMathBlock\(blocks.count)Token"
        }
        let afterInlineMath = replaceMatches(of: inlineMathRegex, in: afterBlockMath) { capture in
            defer { inlines.append(capture) }
            return "MdPreviewMathInline\(inlines.count)Token"
        }

        var processed = afterInlineMath
        for (i, original) in protected.enumerated() {
            processed = processed.replacingOccurrences(
                of: "MdPreviewProtect\(i)Token",
                with: original
            )
        }

        return MathExtraction(processedMarkdown: processed, blocks: blocks, inlines: inlines)
    }

    private static func renderMathBlocks(in html: String,
                                         with math: MathExtraction) -> MathRenderResult {
        guard !math.blocks.isEmpty || !math.inlines.isEmpty else {
            return MathRenderResult(html: html, containsMath: false)
        }

        let nsHtml = html as NSString
        let matches = mathTokenRegex.matches(
            in: html,
            range: NSRange(location: 0, length: nsHtml.length)
        )
        var rebuilt = ""
        rebuilt.reserveCapacity(html.count)
        var cursor = 0
        for match in matches {
            rebuilt += nsHtml.substring(with: NSRange(
                location: cursor,
                length: match.range.location - cursor
            ))
            let kindRange = match.range(at: 1).location != NSNotFound
                ? match.range(at: 1) : match.range(at: 3)
            let indexRange = match.range(at: 2).location != NSNotFound
                ? match.range(at: 2) : match.range(at: 4)
            let isBlock = nsHtml.substring(with: kindRange) == "Block"
            let index = Int(nsHtml.substring(with: indexRange)) ?? 0
            let latex = isBlock ? math.blocks[index] : math.inlines[index]
            let escaped = htmlEscape(latex)
            rebuilt += isBlock
                ? "<div class=\"math math-display\">\(escaped)</div>"
                : "<span class=\"math math-inline\">\(escaped)</span>"
            cursor = match.range.location + match.range.length
        }
        rebuilt += nsHtml.substring(from: cursor)
        return MathRenderResult(html: rebuilt, containsMath: true)
    }

    private static let katexHead: String = {
        guard let js = bundledVendorResource("katex.min", ext: "js", subdir: "Vendor/KaTeX") else {
            return """
            <script>
            window.addEventListener('load', () => {
                document.querySelectorAll('.math').forEach((node) => {
                    node.classList.add('math-error');
                    node.textContent = 'KaTeX renderer is unavailable.\\n\\n' + node.textContent;
                });
            });
            </script>
            """
        }
        let css = bundledVendorResource("katex.min", ext: "css", subdir: "Vendor/KaTeX") ?? ""
        let copyTex = bundledVendorResource("copy-tex.min", ext: "js", subdir: "Vendor/KaTeX") ?? ""
        let safeJS = js.replacingOccurrences(of: "</script", with: "<\\/script")
        let safeCopyTex = copyTex.replacingOccurrences(of: "</script", with: "<\\/script")

        return """
        <style>\(css)</style>
        <script>\(safeJS)</script>
        <script>
        (function() {
            function renderMath() {
                document.querySelectorAll('.math').forEach((el) => {
                    const tex = el.textContent;
                    const display = el.classList.contains('math-display');
                    try {
                        katex.render(tex, el, {
                            displayMode: display,
                            throwOnError: false,
                            output: 'htmlAndMathml'
                        });
                    } catch (err) {
                        el.classList.add('math-error');
                        el.textContent = String((err && err.message) || err);
                    }
                });
            }
            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', renderMath, { once: true });
            } else {
                renderMath();
            }
        })();
        </script>
        \(safeCopyTex.isEmpty ? "" : "<script>\(safeCopyTex)</script>")
        """
    }()

    private static func bundledVendorResource(_ name: String,
                                              ext: String,
                                              subdir: String) -> String? {
        let bundles = [Bundle.main, Bundle(for: MarkdownHTMLBundleToken.self)]
        for bundle in bundles {
            let urls = [
                bundle.url(forResource: name, withExtension: ext, subdirectory: subdir),
                bundle.url(forResource: name, withExtension: ext),
            ]
            for url in urls.compactMap({ $0 }) {
                if let s = try? String(contentsOf: url, encoding: .utf8) { return s }
            }
        }
        return nil
    }

    private static func replaceMatches(of regex: NSRegularExpression,
                                       in source: String,
                                       transform: (String) -> String) -> String {
        rewrite(matchesOf: regex, in: source, captureGroup: 1, transform: transform)
    }

    private static func replaceFullMatches(of regex: NSRegularExpression,
                                           in source: String,
                                           transform: (String) -> String) -> String {
        rewrite(matchesOf: regex, in: source, captureGroup: 0, transform: transform)
    }

    private static func rewrite(matchesOf regex: NSRegularExpression,
                                in source: String,
                                captureGroup: Int,
                                transform: (String) -> String) -> String {
        let nsSource = source as NSString
        let matches = regex.matches(
            in: source,
            range: NSRange(location: 0, length: nsSource.length)
        )
        guard !matches.isEmpty else { return source }
        var result = ""
        result.reserveCapacity(source.count)
        var cursor = 0
        for match in matches {
            result += nsSource.substring(with: NSRange(
                location: cursor,
                length: match.range.location - cursor
            ))
            result += transform(nsSource.substring(with: match.range(at: captureGroup)))
            cursor = match.range.location + match.range.length
        }
        result += nsSource.substring(from: cursor)
        return result
    }

    private static func htmlEscape(_ string: String) -> String {
        var out = ""
        out.reserveCapacity(string.count)
        for ch in string {
            switch ch {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            default: out.append(ch)
            }
        }
        return out
    }

    // MARK: - Mermaid

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
        guard html.contains("language-mermaid") else {
            return MermaidRenderResult(html: html, containsMermaid: false)
        }
        let rendered = replaceMatches(of: mermaidRegex, in: html) { diagram in
            """
            <div class="mermaid" role="img" aria-label="Mermaid diagram">
            \(diagram)
            </div>
            """
        }
        return MermaidRenderResult(html: rendered, containsMermaid: true)
    }

    private static let mermaidScript: String = {
        guard let script = bundledVendorResource("mermaid.min", ext: "js", subdir: "Vendor/Mermaid") else {
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
        let safeScript = script.replacingOccurrences(of: "</script", with: "<\\/script")
        return """
        <script>
        \(safeScript)

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
    }()

    // MARK: - Syntax highlighting (Shiki)

    private struct ShikiRenderResult {
        let html: String
        let containsHighlightedCode: Bool
    }

    private static let highlightableCodeRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: #"<pre><code class="language-[^"]+">"#)
    }()

    private static func detectHighlightableCode(in html: String) -> ShikiRenderResult {
        let nsHtml = html as NSString
        let firstMatch = highlightableCodeRegex.firstMatch(
            in: html,
            range: NSRange(location: 0, length: nsHtml.length)
        )
        return ShikiRenderResult(html: html, containsHighlightedCode: firstMatch != nil)
    }

    private static let shikiScript: String = {
        guard let script = bundledVendorResource("shiki.bundle", ext: "js", subdir: "Vendor/Shiki") else {
            return """
            <script>
            window.addEventListener('load', () => {
                document.querySelectorAll('pre > code[class*="language-"]').forEach((node) => {
                    const pre = node.parentElement;
                    if (!pre || node.classList.contains('language-mermaid')) return;
                    pre.classList.add('shiki-error');
                    pre.setAttribute('data-shiki-error', 'Shiki renderer is unavailable.');
                });
            });
            </script>
            """
        }
        let safeScript = script.replacingOccurrences(of: "</script", with: "<\\/script")
        return """
        <script>
        \(safeScript)

        window.addEventListener('load', async () => {
            if (!window.MdPreviewShiki || !window.MdPreviewShiki.renderAll) return;
            try {
                await window.MdPreviewShiki.renderAll(document);
                window.dispatchEvent(new Event('md-preview-shiki-rendered'));
            } catch (error) {
                document.querySelectorAll('pre > code[class*="language-"]').forEach((node) => {
                    const pre = node.parentElement;
                    if (!pre || node.classList.contains('language-mermaid')) return;
                    pre.classList.add('shiki-error');
                    pre.setAttribute('data-shiki-error', String((error && error.message) || error));
                });
                console.error('Shiki rendering failed', error);
            }
        });
        </script>
        """
    }()

    private static let codeCopyScript = """
    <script>
    (function() {
        function codeText(block) {
            const code = block.querySelector('pre code');
            return code ? code.textContent || '' : '';
        }

        function fallbackCopy(text) {
            const textarea = document.createElement('textarea');
            textarea.value = text;
            textarea.setAttribute('readonly', '');
            textarea.style.position = 'fixed';
            textarea.style.opacity = '0';
            document.body.appendChild(textarea);
            textarea.select();
            try {
                document.execCommand('copy');
            } finally {
                textarea.remove();
            }
        }

        async function copyText(text) {
            if (navigator.clipboard && navigator.clipboard.writeText) {
                try {
                    await navigator.clipboard.writeText(text);
                    return;
                } catch (_) {}
            }
            fallbackCopy(text);
        }

        function setCopied(button) {
            button.classList.add('copied');
            button.setAttribute('aria-label', 'Copied');
            button.title = 'Copied';
            window.setTimeout(() => {
                button.classList.remove('copied');
                button.setAttribute('aria-label', 'Copy code');
                button.title = 'Copy code';
            }, 1200);
        }

        function installCodeCopyButtons() {
            document.querySelectorAll('article.markdown-body pre').forEach((pre) => {
                if (pre.closest('.mermaid')) return;
                let block = pre.closest('.md-code-block');
                if (!block) {
                    block = document.createElement('div');
                    block.className = 'md-code-block';
                    pre.parentNode.insertBefore(block, pre);
                    block.appendChild(pre);
                }
                if (block.querySelector(':scope > .md-code-copy')) return;
                const button = document.createElement('button');
                button.type = 'button';
                button.className = 'md-code-copy';
                button.setAttribute('aria-label', 'Copy code');
                button.title = 'Copy code';
                button.innerHTML = '<svg viewBox="0 0 16 16" aria-hidden="true"><path d="M5 1.75A1.75 1.75 0 0 1 6.75 0h5.5A1.75 1.75 0 0 1 14 1.75v7.5A1.75 1.75 0 0 1 12.25 11h-5.5A1.75 1.75 0 0 1 5 9.25Zm1.75-.25a.25.25 0 0 0-.25.25v7.5c0 .138.112.25.25.25h5.5a.25.25 0 0 0 .25-.25v-7.5a.25.25 0 0 0-.25-.25Z"></path><path d="M2 4.75C2 3.784 2.784 3 3.75 3H4v1.5h-.25a.25.25 0 0 0-.25.25v7.5c0 .138.112.25.25.25h5.5a.25.25 0 0 0 .25-.25V12H11v.25A1.75 1.75 0 0 1 9.25 14h-5.5A1.75 1.75 0 0 1 2 12.25Z"></path></svg>';
                button.addEventListener('click', async () => {
                    await copyText(codeText(block));
                    setCopied(button);
                });
                block.appendChild(button);
            });
        }

        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', installCodeCopyButtons, { once: true });
        } else {
            installCodeCopyButtons();
        }
        window.addEventListener('md-preview-shiki-rendered', installCodeCopyButtons);
    })();
    </script>
    """

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
    .footnote-ref {
        font-size: 0.75em;
        line-height: 0;
        vertical-align: super;
    }
    .footnote-ref a {
        padding: 0 0.12em;
    }
    .footnotes {
        margin-top: 2.35em;
        color: var(--text);
        font-size: 0.9em;
        line-height: 1.45;
    }
    .footnotes hr {
        margin: 0 0 1em;
    }
    .footnotes ol {
        margin-top: 0;
        padding-left: 1.45em;
    }
    .footnotes li {
        margin-top: 0.72em;
        padding-left: 0.12em;
    }
    .footnotes li:first-child {
        margin-top: 0;
    }
    .footnotes li > p:first-child {
        margin-top: 0;
    }
    .footnote-backrefs {
        display: inline-flex;
        gap: 0.28em;
        margin-left: 0.28em;
        white-space: nowrap;
    }
    .footnote-backref {
        font-size: 0.78em;
        opacity: 0.65;
        vertical-align: baseline;
    }
    .footnote-backref:hover {
        opacity: 1;
    }

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
    .md-code-block {
        position: relative;
        margin: 0.8em 0 0;
    }
    .md-code-block pre {
        margin: 0;
        padding-right: 46px;
    }
    .md-code-copy {
        position: absolute;
        top: 8px;
        right: 8px;
        width: 28px;
        height: 28px;
        display: inline-flex;
        align-items: center;
        justify-content: center;
        border: 0;
        border-radius: 7px;
        color: var(--secondary);
        background: color-mix(in srgb, var(--code-bg) 78%, canvas);
        opacity: 0;
        transition: opacity 120ms ease, color 120ms ease, background 120ms ease;
        cursor: pointer;
        -webkit-appearance: none;
    }
    .md-code-block:hover .md-code-copy,
    .md-code-copy:focus-visible,
    .md-code-copy.copied {
        opacity: 1;
    }
    .md-code-copy:hover {
        color: var(--text);
        background: color-mix(in srgb, var(--code-bg) 58%, canvas);
    }
    .md-code-copy.copied {
        color: var(--link);
    }
    .md-code-copy svg {
        width: 15px;
        height: 15px;
        fill: currentColor;
    }
    .shiki,
    .shiki code {
        font-family: ui-monospace, "SF Mono", Menlo, monospace;
    }
    .shiki {
        background: var(--code-bg) !important;
    }
    .shiki code {
        display: block;
        min-width: max-content;
    }
    @media (prefers-color-scheme: dark) {
        .shiki span {
            color: var(--shiki-dark) !important;
            font-style: var(--shiki-dark-font-style) !important;
            font-weight: var(--shiki-dark-font-weight) !important;
            text-decoration: var(--shiki-dark-text-decoration) !important;
        }
    }
    .shiki-error {
        outline: 1px solid rgba(176, 0, 32, 0.35);
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
    .math-display {
        margin: 1.2em 0 0;
        overflow-x: auto;
        overflow-y: hidden;
    }
    .math-display .katex-display {
        margin: 0;
    }
    .math-error {
        color: #b00020;
        background: var(--code-bg);
        padding: 4px 8px;
        border-radius: 6px;
        font-family: ui-monospace, "SF Mono", Menlo, monospace;
        font-size: 0.88em;
        white-space: pre-wrap;
    }
    @media (prefers-color-scheme: dark) {
        .math-error { color: #ff6e6e; }
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
