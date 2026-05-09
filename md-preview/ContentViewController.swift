//
//  ContentViewController.swift
//  md-preview
//

import Cocoa

final class ContentViewController: NSViewController {

    private var webView: MarkdownWebView!
    private var documentHeightConstraint: NSLayoutConstraint!
    private var webViewHeightConstraint: NSLayoutConstraint!
    private var measuredDocumentHeight: CGFloat = 1
    private var lastLaidOutSize: NSSize = .zero
    private var pendingFlashWork: DispatchWorkItem?

    override func loadView() {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let documentView = FlippedDocumentView()
        documentView.translatesAutoresizingMaskIntoConstraints = false

        webView = MarkdownWebView()
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.heightDidChange = { [weak self] height in
            guard let self,
                  abs(height - self.measuredDocumentHeight) > 0.5 else { return }
            self.measuredDocumentHeight = height
            self.applyDocumentHeight()
        }
        webView.fragmentLinkActivated = { [weak self] fragment in
            self?.scrollToElement(id: fragment)
        }

        documentView.addSubview(webView)
        scrollView.documentView = documentView
        view = scrollView

        documentHeightConstraint = documentView.heightAnchor.constraint(equalToConstant: 1)
        webViewHeightConstraint = webView.heightAnchor.constraint(equalToConstant: 1)

        NSLayoutConstraint.activate([
            documentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            documentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            documentHeightConstraint,

            webView.topAnchor.constraint(equalTo: documentView.topAnchor),
            webView.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            webViewHeightConstraint
        ])
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        let laidOutSize = view.bounds.size
        guard laidOutSize != lastLaidOutSize else { return }

        lastLaidOutSize = laidOutSize
        applyDocumentHeight()
    }

    func display(markdown: String, assetBaseURL: URL? = nil) {
        webView.display(markdown: markdown, assetBaseURL: assetBaseURL)
    }

    func clearContent() {
        webView.clearContent()
    }

    func find(_ query: String,
              backwards: Bool = false,
              mode: SearchMode = .contains,
              completion: ((FindResult) -> Void)? = nil) {
        let pasteboard = NSPasteboard(name: .find)
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(query, forType: .string)
        pendingFlashWork?.cancel()
        webView.find(query, backwards: backwards, mode: mode) { [weak self] result in
            guard let self else {
                completion?(result)
                return
            }
            if let top = result.top, let bottom = result.bottom {
                let needsScroll = !self.isMatchVisible(top: top, bottom: bottom)
                if needsScroll {
                    self.scrollDocument(to: top)
                }
                let delay: TimeInterval = needsScroll ? 0.18 : 0
                let work = DispatchWorkItem { [weak self] in
                    self?.webView.flashCurrentMatch()
                }
                self.pendingFlashWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
            }
            completion?(result)
        }
    }

    private func isMatchVisible(top: CGFloat, bottom: CGFloat) -> Bool {
        guard let scrollView = view as? NSScrollView else { return true }
        let clipView = scrollView.contentView
        let visibleTop = clipView.bounds.origin.y + clipView.contentInsets.top
        let visibleBottom = clipView.bounds.origin.y
            + clipView.bounds.height
            - clipView.contentInsets.bottom
        return top >= visibleTop && bottom <= visibleBottom
    }

    func printDocument() {
        guard let window = view.window else { return }
        webView.printDocument(from: window)
    }

    func zoomIn() { webView.zoomIn() }
    func zoomOut() { webView.zoomOut() }
    func resetZoom() { webView.resetZoom() }
    var pageZoom: CGFloat { webView.pageZoom }

    func scrollToHeading(index: Int) {
        webView.headingOffset(index: index) { [weak self] offset in
            guard let self, let offset else { return }
            self.scrollDocument(to: offset)
        }
    }

    private func scrollToElement(id: String) {
        webView.elementOffset(id: id) { [weak self] offset in
            guard let self, let offset else { return }
            self.scrollDocument(to: offset)
        }
    }

    private func scrollDocument(to y: CGFloat) {
        guard let scrollView = view as? NSScrollView else { return }
        let clipView = scrollView.contentView
        let topInset = clipView.contentInsets.top
        let bottomInset = clipView.contentInsets.bottom
        let topMargin: CGFloat = 12
        let adjusted = y - topInset - topMargin
        let minY = -topInset
        let maxY = max(documentHeightConstraint.constant - clipView.bounds.height + bottomInset, minY)
        let target = max(minY, min(adjusted, maxY))
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.allowsImplicitAnimation = true
            clipView.animator().setBoundsOrigin(NSPoint(x: clipView.bounds.origin.x, y: target))
        }
        scrollView.reflectScrolledClipView(clipView)
    }

    private func applyDocumentHeight() {
        let resolvedHeight = max(measuredDocumentHeight, view.bounds.height, 1)
        documentHeightConstraint.constant = resolvedHeight
        webViewHeightConstraint.constant = resolvedHeight
        clampScrollPosition(toDocumentHeight: resolvedHeight)
    }

    private func clampScrollPosition(toDocumentHeight documentHeight: CGFloat) {
        guard let scrollView = view as? NSScrollView else { return }

        let clipView = scrollView.contentView
        let maxY = max(documentHeight - clipView.bounds.height, 0)
        guard clipView.bounds.origin.y > maxY else {
            scrollView.reflectScrolledClipView(clipView)
            return
        }

        clipView.scroll(to: NSPoint(x: clipView.bounds.origin.x, y: maxY))
        scrollView.reflectScrolledClipView(clipView)
    }
}

private final class FlippedDocumentView: NSView {
    override var isFlipped: Bool { true }
}
