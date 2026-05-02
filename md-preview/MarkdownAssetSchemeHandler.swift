//
//  MarkdownAssetSchemeHandler.swift
//  md-preview
//

import Foundation
import UniformTypeIdentifiers
import WebKit

/// Custom URL scheme handler that serves files relative to the document's
/// parent folder. The host process holds the security-scoped extension for
/// the folder, so FileManager reads succeed even though the WKWebView's
/// content process is sandboxed separately.
final class MarkdownAssetScheme: NSObject, WKURLSchemeHandler {

    static let scheme = "md-asset"

    private let queue = DispatchQueue(label: "doc.md-preview.asset-scheme", qos: .userInitiated)
    private let lock = NSLock()
    private var _baseURL: URL?

    var baseURL: URL? {
        get {
            lock.lock(); defer { lock.unlock() }
            return _baseURL
        }
        set {
            lock.lock(); defer { lock.unlock() }
            _baseURL = newValue
        }
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        let request = urlSchemeTask.request
        let base = baseURL
        let wrapper = TaskWrapper(task: urlSchemeTask)

        queue.async {
            guard let base, let requestURL = request.url else {
                wrapper.task.didFailWithError(URLError(.badURL))
                return
            }

            // The path-stripping leaves us with just the relative bit so we
            // can resolve safely against the granted base directory.
            guard let resolved = Self.resolve(requestURL: requestURL, against: base) else {
                wrapper.task.didFailWithError(URLError(.unsupportedURL))
                return
            }

            do {
                let data = try Data(contentsOf: resolved)
                let mime = Self.mimeType(for: resolved)
                let response = HTTPURLResponse(
                    url: requestURL,
                    statusCode: 200,
                    httpVersion: "HTTP/1.1",
                    headerFields: [
                        "Content-Type": mime,
                        "Content-Length": String(data.count),
                        "Access-Control-Allow-Origin": "*"
                    ]
                ) ?? URLResponse(url: requestURL,
                                 mimeType: mime,
                                 expectedContentLength: data.count,
                                 textEncodingName: nil)
                wrapper.task.didReceive(response)
                wrapper.task.didReceive(data)
                wrapper.task.didFinish()
            } catch {
                wrapper.task.didFailWithError(URLError(.fileDoesNotExist))
            }
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {
        // No persistent task state to cancel — reads are synchronous on the queue.
    }

    private struct TaskWrapper: @unchecked Sendable {
        let task: any WKURLSchemeTask
    }

    private static func resolve(requestURL: URL, against base: URL) -> URL? {
        // md-asset:///images/foo.png → path = "/images/foo.png"
        var path = requestURL.path
        while path.hasPrefix("/") {
            path.removeFirst()
        }
        guard !path.isEmpty else { return nil }

        let candidate = base.appendingPathComponent(path).standardizedFileURL
        let baseStandardized = base.standardizedFileURL
        // Reject path traversal that escapes the granted folder.
        guard candidate.path.hasPrefix(baseStandardized.path + "/")
                || candidate.path == baseStandardized.path else {
            return nil
        }
        return candidate
    }

    private static func mimeType(for url: URL) -> String {
        if let type = UTType(filenameExtension: url.pathExtension),
           let mime = type.preferredMIMEType {
            return mime
        }
        return "application/octet-stream"
    }
}
