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

    func setBaseURL(_ url: URL?) {
        lock.lock(); defer { lock.unlock() }
        _baseURL = url
    }

    private func currentBaseURL() -> URL? {
        lock.lock(); defer { lock.unlock() }
        return _baseURL
    }

    /// Resolves an `md-asset://…` URL against `base`, rejecting path-traversal
    /// that escapes the granted folder. Returns `nil` for malformed input.
    static func resolve(_ assetURL: URL, against base: URL) -> URL? {
        var path = assetURL.path
        while path.hasPrefix("/") { path.removeFirst() }
        guard !path.isEmpty else { return nil }

        let candidate = base.appendingPathComponent(path).standardizedFileURL
        let basePath = base.standardizedFileURL.path
        guard candidate.path == basePath
                || candidate.path.hasPrefix(basePath + "/") else {
            return nil
        }
        return candidate
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        let request = urlSchemeTask.request
        let base = currentBaseURL()
        let wrapper = TaskWrapper(task: urlSchemeTask)

        queue.async {
            guard let base, let requestURL = request.url,
                  let resolved = Self.resolve(requestURL, against: base) else {
                wrapper.task.didFailWithError(URLError(.badURL))
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

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {}

    private struct TaskWrapper: @unchecked Sendable {
        let task: any WKURLSchemeTask
    }

    private static func mimeType(for url: URL) -> String {
        UTType(filenameExtension: url.pathExtension)?.preferredMIMEType
            ?? "application/octet-stream"
    }
}
