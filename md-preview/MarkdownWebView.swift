//
//  MarkdownWebView.swift
//  md-preview
//

import Cocoa
import os
import WebKit

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "doc.md-preview"
    static let perf = Logger(subsystem: subsystem, category: "perf")
}

enum SearchMode {
    case contains
    case beginsWith
}

struct FindResult {
    let top: CGFloat?
    let bottom: CGFloat?
    let index: Int
    let total: Int

    static let none = FindResult(top: nil, bottom: nil, index: 0, total: 0)
}

final class MarkdownWebView: NSView, WKNavigationDelegate {

    let webView: WKWebView
    var heightDidChange: ((CGFloat) -> Void)?
    var fragmentLinkActivated: ((String) -> Void)?
    private let assetScheme = MarkdownAssetScheme()
    private var currentAssetBase: URL?
    private let messageBridge = HostBridge()

    private struct RendererFingerprint: Equatable {
        let math: Bool
        let mermaid: Bool
        let code: Bool

        /// True if every renderer the new doc needs is already loaded — the
        /// gate for the fast-path innerHTML swap.
        func covers(_ other: RendererFingerprint) -> Bool {
            (!other.math || math)
                && (!other.mermaid || mermaid)
                && (!other.code || code)
        }
    }
    private var loadedFingerprint: RendererFingerprint?
    private var isPageReady = false

    override init(frame frameRect: NSRect) {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(assetScheme, forURLScheme: MarkdownAssetScheme.scheme)
        config.userContentController.add(messageBridge, name: HostBridge.name)
        webView = NonScrollingWKWebView(frame: .zero, configuration: config)
        super.init(frame: frameRect)

        messageBridge.owner = self
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        DispatchQueue.main.async { [weak self] in
            self?.neutralizeWebKitScrollEdgeInsets()
            self?.warmupVendors()
        }
    }

    /// Synthetic markdown that flips every renderer flag (math + mermaid +
    /// code). Loaded into the WebView at launch so the heavy vendor JS is
    /// parsed and executed before the user picks a real file. Every later
    /// `display()` call then hits the fast-path (innerHTML swap + reapplier
    /// sweep) instead of paying for a full reload.
    private static let warmupMarkdown = """
    $x$

    ```mermaid
    graph TD; A-->B
    ```

    ```typescript
    let x: string = 'warmup';
    ```
    """

    private func warmupVendors() {
        guard !isPageReady, loadedFingerprint == nil else { return }
        let baseHref = "\(MarkdownAssetScheme.scheme):///"
        let rendered = MarkdownHTML.render(markdown: Self.warmupMarkdown,
                                           assetBaseHref: baseHref,
                                           vendorLoading: .lazy,
                                           warmup: true)
        loadedFingerprint = RendererFingerprint(
            math: rendered.containsMath,
            mermaid: rendered.containsMermaid,
            code: rendered.containsCode
        )
        webView.loadHTMLString(rendered.html, baseURL: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        neutralizeWebKitScrollEdgeInsets()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        neutralizeWebKitScrollEdgeInsets()
    }

    /// Empties the visible article without unloading the page, so the next
    /// `display()` still hits the fast-path.
    func clearContent() {
        guard isPageReady else { return }
        webView.evaluateJavaScript("window.MdPreview && MdPreview.update('');") { _, _ in }
    }

    func display(markdown: String, assetBaseURL: URL? = nil) {
        assetScheme.setBaseURL(assetBaseURL)
        let baseHref = "\(MarkdownAssetScheme.scheme):///"
        let rendered = MarkdownHTML.render(markdown: markdown,
                                           assetBaseHref: baseHref,
                                           vendorLoading: .lazy)
        let fingerprint = RendererFingerprint(
            math: rendered.containsMath,
            mermaid: rendered.containsMermaid,
            code: rendered.containsCode
        )
        currentAssetBase = assetBaseURL

        // Fast path: the loaded page already has every renderer the new doc
        // needs — swap the article body via JS instead of reloading the
        // WKWebView (which would re-parse and re-execute the multi-MB vendor
        // bundles). The launch-time warmup loads both vendors, so any
        // subsequent file with any subset of renderers fast-paths into it.
        if isPageReady, let loaded = loadedFingerprint, loaded.covers(fingerprint) {
            let payload = javaScriptStringLiteral(rendered.articleHTML)
            webView.evaluateJavaScript("window.MdPreview && MdPreview.update(\(payload));") { _, _ in }
            return
        }

        webView.loadHTMLString(rendered.html, baseURL: nil)
        loadedFingerprint = fingerprint
        isPageReady = false
    }

    fileprivate func didReceiveHostMessage(_ body: Any) {
        guard let dict = body as? [String: Any],
              let kind = dict["kind"] as? String else { return }
        switch kind {
        case "height":
            guard let value = dict["value"] as? NSNumber else { return }
            heightDidChange?(ceil(CGFloat(truncating: value)))
        case "log":
            // MdPreviewPerf.log() — debug-only; release builds never post.
            // Routed through os.Logger so `log stream --level=debug
            // --predicate 'subsystem == "doc.md-preview"'` surfaces them.
            guard let message = dict["message"] as? String else { return }
            Logger.perf.debug("\(message, privacy: .public)")
        default:
            break
        }
    }

    func find(_ query: String,
              backwards: Bool = false,
              mode: SearchMode = .contains,
              completion: ((FindResult) -> Void)? = nil) {
        highlightMatches(for: query, backwards: backwards, mode: mode, completion: completion)
    }

    /// Flashes the macOS-style "burst" animation over the current match —
    /// a yellow rounded rect that starts large and shrinks down to the match.
    func flashCurrentMatch() {
        let script = """
        (() => {
            const root = document.querySelector('.markdown-body') || document.body;
            const marks = root.querySelectorAll('mark.md-search-highlight');
            const index = window.__mdPreviewSearchIndex;
            if (!Number.isInteger(index) || index < 0 || index >= marks.length) return;
            // Drop any in-flight burst so fast typing doesn't pile elements
            // on the body waiting to fire animationend.
            document.querySelectorAll('.md-search-burst').forEach(b => b.remove());
            const target = marks[index];
            const rect = target.getBoundingClientRect();
            const scrollX = window.scrollX || document.documentElement.scrollLeft || 0;
            const scrollY = window.scrollY || document.documentElement.scrollTop || 0;
            const padX = 6;
            const padY = 4;
            const burst = document.createElement('span');
            burst.className = 'md-search-burst';
            burst.style.left = (rect.left + scrollX - padX) + 'px';
            burst.style.top = (rect.top + scrollY - padY) + 'px';
            burst.style.width = (rect.width + padX * 2) + 'px';
            burst.style.height = (rect.height + padY * 2) + 'px';
            document.body.appendChild(burst);
            burst.addEventListener('animationend', () => burst.remove(), { once: true });
        })();
        """
        webView.evaluateJavaScript(script) { _, _ in }
    }

    func printDocument(from window: NSWindow) {
        let printInfo = NSPrintInfo.shared.copy() as? NSPrintInfo ?? NSPrintInfo()
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.isHorizontallyCentered = true
        printInfo.isVerticallyCentered = false

        let operation = webView.printOperation(with: printInfo)
        operation.jobTitle = window.title
        // WKWebView's print view needs an explicit frame, otherwise AppKit
        // asserts in `runModal` when the operation tries to lay out at zero
        // size — Apple's documented pattern.
        operation.view?.frame = webView.bounds
        operation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
    }

    func headingOffset(index: Int, completion: @escaping (CGFloat?) -> Void) {
        let script = """
        (() => {
            const el = document.getElementById('md-heading-\(index)');
            if (!el) return null;
            const rect = el.getBoundingClientRect();
            return rect.top + (window.scrollY || document.documentElement.scrollTop || 0);
        })();
        """
        webView.evaluateJavaScript(script) { result, _ in
            if let number = result as? NSNumber {
                completion(CGFloat(truncating: number))
            } else {
                completion(nil)
            }
        }
    }

    func elementOffset(id: String, completion: @escaping (CGFloat?) -> Void) {
        let script = """
        (() => {
            const el = document.getElementById(\(javaScriptStringLiteral(id)));
            if (!el) return null;
            const rect = el.getBoundingClientRect();
            return rect.top + (window.scrollY || document.documentElement.scrollTop || 0);
        })();
        """
        webView.evaluateJavaScript(script) { result, _ in
            if let number = result as? NSNumber {
                completion(CGFloat(truncating: number))
            } else {
                completion(nil)
            }
        }
    }

    private func highlightMatches(for query: String,
                                  backwards: Bool,
                                  mode: SearchMode,
                                  completion: ((FindResult) -> Void)?) {
        let beginsWith = mode == .beginsWith
        let script = """
        (() => {
            const root = document.querySelector('.markdown-body') || document.body;
            const previousQuery = window.__mdPreviewSearchQuery || '';
            const previousBeginsWith = window.__mdPreviewSearchBeginsWith === true;
            const beginsWith = \(beginsWith ? "true" : "false");
            const sameQuery = previousQuery === \(javaScriptStringLiteral(query))
                && previousBeginsWith === beginsWith;

            // Tear down prior highlights, but only normalize() the parents we
            // actually touched — root.normalize() is O(N) over the entire
            // document subtree, which is the dominant stall on big docs.
            const priorMarks = root.querySelectorAll('mark.md-search-highlight');
            if (priorMarks.length > 0) {
                const dirty = new Set();
                priorMarks.forEach((mark) => {
                    const parent = mark.parentNode;
                    if (parent) dirty.add(parent);
                    mark.replaceWith(document.createTextNode(mark.textContent));
                });
                dirty.forEach((parent) => parent.normalize());
            }

            const query = \(javaScriptStringLiteral(query));
            window.__mdPreviewSearchQuery = query;
            window.__mdPreviewSearchBeginsWith = beginsWith;
            if (!query) {
                window.__mdPreviewSearchIndex = -1;
                return { top: null, bottom: null, index: 0, total: 0 };
            }
            const isWordChar = (ch) => /[A-Za-z0-9_]/.test(ch);

            const needle = query.toLocaleLowerCase();
            // checkVisibility() forces layout, and KaTeX/Mermaid pages have
            // many text nodes per parent — cache by parent so we hit it once.
            const visibilityCache = new WeakMap();
            const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, {
                acceptNode(node) {
                    const parent = node.parentElement;
                    if (!parent || parent.closest('script, style, textarea, mark.md-search-highlight')) {
                        return NodeFilter.FILTER_REJECT;
                    }
                    // KaTeX/Mermaid stash hidden MathML / source mirrors with
                    // getBoundingClientRect.top===0 — scrolling to those would
                    // jump the doc to the top with nothing visible.
                    let visible = visibilityCache.get(parent);
                    if (visible === undefined) {
                        visible = typeof parent.checkVisibility !== 'function'
                            || parent.checkVisibility();
                        visibilityCache.set(parent, visible);
                    }
                    if (!visible) return NodeFilter.FILTER_REJECT;
                    // Don't double-lowercase here; the inner loop already does
                    // one .toLocaleLowerCase() per node and an .indexOf, which
                    // short-circuits cheaply on non-matching text.
                    return NodeFilter.FILTER_ACCEPT;
                }
            });

            const nodes = [];
            while (walker.nextNode()) { nodes.push(walker.currentNode); }

            const marks = [];
            for (const node of nodes) {
                const text = node.nodeValue;
                const lower = text.toLocaleLowerCase();
                const fragment = document.createDocumentFragment();
                let offset = 0;
                let searchFrom = 0;
                let matchIndex = lower.indexOf(needle, searchFrom);
                let nodeHasMatch = false;

                while (matchIndex !== -1) {
                    const prevChar = matchIndex === 0 ? '' : text[matchIndex - 1];
                    const isBoundary = matchIndex === 0 || !isWordChar(prevChar);

                    if (!beginsWith || isBoundary) {
                        fragment.append(document.createTextNode(text.slice(offset, matchIndex)));

                        const mark = document.createElement('mark');
                        mark.className = 'md-search-highlight';
                        mark.textContent = text.slice(matchIndex, matchIndex + query.length);
                        fragment.append(mark);
                        marks.push(mark);

                        offset = matchIndex + query.length;
                        searchFrom = offset;
                        nodeHasMatch = true;
                    } else {
                        // Skip this match, but keep scanning the same text node.
                        searchFrom = matchIndex + 1;
                    }
                    matchIndex = lower.indexOf(needle, searchFrom);
                }

                if (nodeHasMatch) {
                    fragment.append(document.createTextNode(text.slice(offset)));
                    node.replaceWith(fragment);
                }
            }

            if (marks.length === 0) {
                window.__mdPreviewSearchIndex = -1;
                return { top: null, bottom: null, index: 0, total: 0 };
            }

            const previousIndex = Number.isInteger(window.__mdPreviewSearchIndex)
                ? window.__mdPreviewSearchIndex
                : -1;
            const backwards = \(backwards ? "true" : "false");
            let index;

            if (!sameQuery || previousIndex < 0) {
                index = backwards ? marks.length - 1 : 0;
            } else if (backwards) {
                index = (previousIndex - 1 + marks.length) % marks.length;
            } else {
                index = (previousIndex + 1) % marks.length;
            }

            window.__mdPreviewSearchIndex = index;
            const current = marks[index];
            current.classList.add('md-search-highlight-current');

            // The WKWebView host disables internal scrolling and forwards it to
            // an outer NSScrollView, so scrollIntoView() is a no-op. Hand the
            // document-space bounds back so AppKit can scroll the clip view —
            // and only when the match isn't already on screen.
            const rect = current.getBoundingClientRect();
            const scrollY = window.scrollY || document.documentElement.scrollTop || 0;
            return {
                top: rect.top + scrollY,
                bottom: rect.bottom + scrollY,
                index: index + 1,
                total: marks.length
            };
        })();
        """
        webView.evaluateJavaScript(script) { result, _ in
            guard let completion else { return }
            let dict = result as? [String: Any]
            let top = (dict?["top"] as? NSNumber).map { CGFloat(truncating: $0) }
            let bottom = (dict?["bottom"] as? NSNumber).map { CGFloat(truncating: $0) }
            let index = (dict?["index"] as? NSNumber)?.intValue ?? 0
            let total = (dict?["total"] as? NSNumber)?.intValue ?? 0
            completion(FindResult(top: top, bottom: bottom, index: index, total: total))
        }
    }

    private func javaScriptStringLiteral(_ string: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [string]),
              let json = String(data: data, encoding: .utf8),
              json.count >= 2 else { return "\"\"" }
        return String(json.dropFirst().dropLast())
    }

    private func neutralizeWebKitScrollEdgeInsets() {
        let zeroInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        for view in webView.descendantViews {
            if let scrollView = view as? NSScrollView {
                scrollView.automaticallyAdjustsContentInsets = false
                scrollView.hasVerticalScroller = false
                scrollView.hasHorizontalScroller = false
                scrollView.autohidesScrollers = true
                scrollView.verticalScrollElasticity = .none
                scrollView.horizontalScrollElasticity = .none
                scrollView.contentInsets = zeroInsets
                scrollView.scrollerInsets = zeroInsets
                scrollView.verticalScroller?.isHidden = true
                scrollView.verticalScroller?.alphaValue = 0
                scrollView.horizontalScroller?.isHidden = true
                scrollView.horizontalScroller?.alphaValue = 0
            }
            if let scroller = view as? NSScroller {
                scroller.isHidden = true
                scroller.alphaValue = 0
            }
            if let clipView = view as? NSClipView {
                clipView.automaticallyAdjustsContentInsets = false
                clipView.contentInsets = zeroInsets
            }
        }
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
        if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
            if let fragment = sameDocumentFragmentID(from: url) {
                fragmentLinkActivated?(fragment)
            } else if url.scheme == MarkdownAssetScheme.scheme,
               let base = currentAssetBase,
               let resolved = MarkdownAssetScheme.resolve(url, against: base) {
                NSWorkspace.shared.open(resolved)
            } else if url.scheme != MarkdownAssetScheme.scheme {
                NSWorkspace.shared.open(url)
            }
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        neutralizeWebKitScrollEdgeInsets()
        isPageReady = true
    }

    private func sameDocumentFragmentID(from url: URL) -> String? {
        guard let fragment = url.fragment?.removingPercentEncoding,
              !fragment.isEmpty,
              url.query == nil else { return nil }

        if url.scheme == nil {
            return fragment
        }
        if url.scheme == "about", url.absoluteString.hasPrefix("about:blank#") {
            return fragment
        }
        if url.scheme == MarkdownAssetScheme.scheme,
           (url.host == nil || url.host == ""),
           (url.path.isEmpty || url.path == "/") {
            return fragment
        }
        return nil
    }
}

private extension NSView {
    var descendantViews: [NSView] {
        subviews + subviews.flatMap(\.descendantViews)
    }
}

private final class NonScrollingWKWebView: WKWebView {
    private enum Axis { case horizontal, vertical }
    private var lockedAxis: Axis?

    override func scrollWheel(with event: NSEvent) {
        let axis = decideAxis(for: event)
        if axis == .horizontal {
            // Inner overflow:auto element (wide <pre>, table, math) handles it.
            super.scrollWheel(with: event)
            return
        }
        if let outerScrollView = superview?.enclosingScrollView {
            outerScrollView.scrollWheel(with: event)
        } else {
            super.scrollWheel(with: event)
        }
    }

    /// Lock routing axis at the start of a trackpad gesture and carry it
    /// through .changed/.ended and any momentum that follows. Without this,
    /// a momentary Y-dominant event mid-horizontal-swipe routes one frame
    /// to the outer page scroller and the user sees a lurch. Mouse-wheel
    /// events (phase empty) clear the lock and decide per-event.
    private func decideAxis(for event: NSEvent) -> Axis {
        let perEvent: Axis = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY)
            ? .horizontal : .vertical

        if event.phase == .began {
            lockedAxis = perEvent
            return perEvent
        }

        let isTrackpadEvent = !event.phase.isEmpty || !event.momentumPhase.isEmpty
        if isTrackpadEvent, let locked = lockedAxis {
            if event.momentumPhase == .ended || event.momentumPhase == .cancelled {
                lockedAxis = nil
            }
            return locked
        }

        lockedAxis = nil
        return perEvent
    }
}

// Receives postMessage() calls from the page's host-bridge script. Held weakly
// by the WKUserContentController via this proxy so the MarkdownWebView itself
// is free to deallocate without a retain cycle through the config.
private final class HostBridge: NSObject, WKScriptMessageHandler {
    static let name = "mdPreviewHost"
    weak var owner: MarkdownWebView?

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard message.name == HostBridge.name else { return }
        owner?.didReceiveHostMessage(message.body)
    }
}
