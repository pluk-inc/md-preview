//
//  PreviewProvider.swift
//  quick-look
//
//  Created by Fauzaan on 4/28/26.
//

import Cocoa
import Quartz
import UniformTypeIdentifiers

class PreviewProvider: QLPreviewProvider, QLPreviewingController {

    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let text = try String(contentsOf: request.fileURL, encoding: .utf8)
        let html = MarkdownHTML.makeHTML(from: text, allowsScroll: true)

        return QLPreviewReply(
            dataOfContentType: .html,
            contentSize: CGSize(width: 900, height: 900)
        ) { replyToUpdate in
            replyToUpdate.stringEncoding = .utf8
            return Data(html.utf8)
        }
    }
}
