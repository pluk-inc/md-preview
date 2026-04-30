//
//  InspectorView.swift
//  md-preview
//

import SwiftUI

struct DocumentMetadata: Equatable {
    var fileName: String = ""
    var wordCount: Int = 0
    var characterCount: Int = 0
    var lineCount: Int = 0
    var headingCount: Int = 0
    var linkCount: Int = 0
    var imageCount: Int = 0
    var modifiedDate: Date?
    var fileSize: Int64?
}

extension DocumentMetadata {
    static func make(url: URL?, markdown: String) -> DocumentMetadata {
        var meta = DocumentMetadata()
        meta.fileName = url?.lastPathComponent ?? "Untitled"
        meta.characterCount = markdown.count
        meta.wordCount = markdown.split { $0.isWhitespace }.count
        meta.lineCount = markdown.isEmpty ? 0 : markdown.components(separatedBy: .newlines).count
        meta.headingCount = markdown.components(separatedBy: .newlines)
            .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("#") }.count
        let totalRefs = max(0, markdown.components(separatedBy: "](").count - 1)
        meta.imageCount = max(0, markdown.components(separatedBy: "![").count - 1)
        meta.linkCount = max(0, totalRefs - meta.imageCount)

        if let url,
           let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) {
            meta.modifiedDate = attrs[.modificationDate] as? Date
            meta.fileSize = (attrs[.size] as? NSNumber)?.int64Value
        }
        return meta
    }
}

struct InspectorView: View {
    let metadata: DocumentMetadata

    var body: some View {
        Form {
            Section {
                LabeledContent("File Name", value: metadata.fileName)
                LabeledContent("Document Type", value: "Markdown Document")
                if let size = metadata.fileSize {
                    LabeledContent("File Size", value: size.formatted(.byteCount(style: .file)))
                }
            }

            Section {
                LabeledContent("Words", value: metadata.wordCount.formatted())
                LabeledContent("Characters", value: metadata.characterCount.formatted())
                LabeledContent("Lines", value: metadata.lineCount.formatted())
            }

            Section {
                LabeledContent("Headings", value: metadata.headingCount.formatted())
                LabeledContent("Links", value: metadata.linkCount.formatted())
                LabeledContent("Images", value: metadata.imageCount.formatted())
            }

            if let modified = metadata.modifiedDate {
                Section {
                    LabeledContent("Modified") {
                        Text(modified, format: .dateTime.year().month().day().hour().minute())
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
