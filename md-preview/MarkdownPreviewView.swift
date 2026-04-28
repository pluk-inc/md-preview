//
//  MarkdownPreviewView.swift
//  md-preview
//

import SwiftUI
import MarkdownUI

struct MarkdownPreviewView: View {
    let markdown: String

    var body: some View {
        ScrollView {
            Markdown(markdown)
                .markdownTheme(.gitHub)
                .textSelection(.enabled)
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
