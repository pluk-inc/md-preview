//
//  ContentViewController.swift
//  md-preview
//

import Cocoa
import SwiftUI

final class ContentViewController: NSViewController {

    override func loadView() {
        let host = NSHostingView(rootView: MarkdownPreviewView(markdown: SampleMarkdown.demo))
        host.translatesAutoresizingMaskIntoConstraints = false
        view = host
    }
}
