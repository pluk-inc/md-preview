//
//  MarkdownFrontmatter.swift
//  md-preview
//

import Foundation

struct FrontmatterEntry: Equatable, Identifiable {
    let id: Int
    let key: String
    let value: String
}

// Swift-markdown is CommonMark: it has no YAML frontmatter notion, so a closing
// `---` would otherwise turn the preceding lines into a setext H2 in the
// rendered output. We strip the block before parsing and surface the parsed
// entries in the Inspector instead.
nonisolated enum MarkdownFrontmatter {

    static func split(_ markdown: String) -> (raw: String?, body: String) {
        let stripped = markdown.first == "\u{FEFF}" ? String(markdown.dropFirst()) : markdown
        var lines: [String] = []
        stripped.enumerateLines { line, _ in lines.append(line) }

        guard let first = lines.first,
              first.trimmingCharacters(in: .whitespaces) == "---"
        else { return (nil, markdown) }

        guard let close = lines.dropFirst().firstIndex(where: {
            let trimmed = $0.trimmingCharacters(in: .whitespaces)
            return trimmed == "---" || trimmed == "..."
        }) else { return (nil, markdown) }

        let raw = lines[1..<close].joined(separator: "\n")
        let body = lines[(close + 1)...].joined(separator: "\n")
        return (raw, body)
    }

    // Best-effort parse: each top-level `key: value` line becomes an entry;
    // indented continuation lines append to the previous value. We don't
    // interpret YAML types — values are shown verbatim in the Inspector.
    static func parse(_ raw: String) -> [FrontmatterEntry] {
        var entries: [FrontmatterEntry] = []
        for rawLine in raw.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }

            if line.first == " " || line.first == "\t", !entries.isEmpty {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let prev = entries[entries.count - 1]
                let combined = prev.value.isEmpty ? trimmed : "\(prev.value) \(trimmed)"
                entries[entries.count - 1] = FrontmatterEntry(id: prev.id, key: prev.key, value: combined)
                continue
            }

            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            entries.append(FrontmatterEntry(id: entries.count, key: key, value: value))
        }
        return entries
    }
}
