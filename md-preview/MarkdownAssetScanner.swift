//
//  MarkdownAssetScanner.swift
//  md-preview
//

import Foundation

enum MarkdownAssetScanner {

    /// Returns true when the markdown text contains an image or link reference
    /// to a relative local path (so we should ask for folder access). Skips
    /// fenced code blocks, inline code, absolute paths, and any URL with a
    /// scheme (http, https, mailto, data, etc.).
    static func hasRelativeLocalRefs(_ markdown: String) -> Bool {
        let stripped = stripCode(markdown)
        let nsString = stripped as NSString
        let range = NSRange(location: 0, length: nsString.length)

        for match in inlineRefRegex.matches(in: stripped, range: range) {
            let dest = nsString.substring(with: match.range(at: 1))
            if isRelativeLocal(dest) { return true }
        }
        for match in referenceDefinitionRegex.matches(in: stripped, range: range) {
            let dest = nsString.substring(with: match.range(at: 1))
            if isRelativeLocal(dest) { return true }
        }
        return false
    }

    private static let inlineRefRegex: NSRegularExpression = {
        // ![alt](dest) or [text](dest), capturing dest up to space, ), or "
        // swiftlint:disable:next force_try
        try! NSRegularExpression(
            pattern: #"!?\[[^\]]*\]\(\s*<?([^\s)>]+)>?[^)]*\)"#
        )
    }()

    private static let referenceDefinitionRegex: NSRegularExpression = {
        // [label]: dest "title"
        // swiftlint:disable:next force_try
        try! NSRegularExpression(
            pattern: #"(?m)^\s{0,3}\[[^\]]+\]:\s*<?([^\s>]+)>?"#
        )
    }()

    private static func isRelativeLocal(_ destination: String) -> Bool {
        let trimmed = destination.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        if trimmed.hasPrefix("#") { return false }
        if trimmed.hasPrefix("/") { return false }
        if trimmed.hasPrefix("~") { return false }
        if let scheme = URL(string: trimmed)?.scheme, !scheme.isEmpty { return false }
        // Pure fragments / queries already filtered above.
        return true
    }

    /// Remove fenced code blocks and inline code spans so destinations inside
    /// them don't trigger a prompt.
    private static func stripCode(_ markdown: String) -> String {
        var result = ""
        result.reserveCapacity(markdown.count)
        var inFence = false
        for line in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.drop(while: { $0 == " " })
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                inFence.toggle()
                result.append("\n")
                continue
            }
            if inFence {
                result.append("\n")
                continue
            }
            result.append(stripInlineCode(String(line)))
            result.append("\n")
        }
        return result
    }

    private static func stripInlineCode(_ line: String) -> String {
        var result = ""
        result.reserveCapacity(line.count)
        var inCode = false
        for char in line {
            if char == "`" {
                inCode.toggle()
                result.append(" ")
                continue
            }
            result.append(inCode ? " " : char)
        }
        return result
    }
}
