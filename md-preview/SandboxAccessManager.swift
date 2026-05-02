//
//  SandboxAccessManager.swift
//  md-preview
//

import AppKit
import Foundation

@MainActor
final class SandboxAccessManager {

    static let shared = SandboxAccessManager()

    private static let bookmarkKeyPrefix = "MarkdownPreview.folderBookmark."
    private static let declinedKeyPrefix = "MarkdownPreview.folderDeclined."

    private var activeAccess: [URL: URL] = [:]

    private init() {}

    /// Returns access to the parent folder of `fileURL` if it's already active
    /// (under any granted ancestor) or restorable from a saved bookmark. Never
    /// prompts the user.
    func currentAccessURL(forParentOf fileURL: URL) -> URL? {
        let parent = fileURL.deletingLastPathComponent()
        if let active = activeContaining(parent) { return active }
        return restoreAccess(for: parent)
    }

    func hasDeclined(forParentOf fileURL: URL) -> Bool {
        let parent = fileURL.deletingLastPathComponent()
        return UserDefaults.standard.bool(forKey: Self.declinedKey(for: parent))
    }

    func markDeclined(forParentOf fileURL: URL) {
        let parent = fileURL.deletingLastPathComponent()
        UserDefaults.standard.set(true, forKey: Self.declinedKey(for: parent))
        UserDefaults.standard.removeObject(forKey: Self.bookmarkKey(for: parent))
    }

    /// Prompt the user (Powerbox) for access to the parent folder. Returns the
    /// granted URL or `nil` if the user cancelled.
    @discardableResult
    func requestAccess(forParentOf fileURL: URL) -> URL? {
        let parent = fileURL.deletingLastPathComponent()
        if let active = activeContaining(parent) { return active }
        if let restored = restoreAccess(for: parent) { return restored }
        guard let granted = promptForAccess(to: parent) else { return nil }
        UserDefaults.standard.removeObject(forKey: Self.declinedKey(for: parent))
        return granted
    }

    func releaseAllAccess() {
        for url in activeAccess.values {
            url.stopAccessingSecurityScopedResource()
        }
        activeAccess.removeAll()
    }

    private func activeContaining(_ folderURL: URL) -> URL? {
        let target = folderURL.standardizedFileURL.path
        for granted in activeAccess.values {
            let base = granted.standardizedFileURL.path
            if target == base || target.hasPrefix(base + "/") {
                return granted
            }
        }
        return nil
    }

    private func restoreAccess(for folderURL: URL) -> URL? {
        let key = Self.bookmarkKey(for: folderURL)
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }

        var isStale = false
        let resolved: URL
        do {
            resolved = try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        } catch {
            UserDefaults.standard.removeObject(forKey: key)
            return nil
        }

        guard resolved.startAccessingSecurityScopedResource() else {
            UserDefaults.standard.removeObject(forKey: key)
            return nil
        }

        if isStale, let refreshed = try? resolved.bookmarkData(options: .withSecurityScope) {
            UserDefaults.standard.set(refreshed, forKey: key)
        }

        activeAccess[resolved] = resolved
        return resolved
    }

    private func promptForAccess(to folderURL: URL) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.directoryURL = folderURL
        panel.prompt = "Grant Access"
        panel.message = "Markdown Preview needs access to “\(folderURL.lastPathComponent)” to display local images and other relative assets. This is a one-time prompt per folder."

        guard panel.runModal() == .OK, let granted = panel.url else { return nil }

        do {
            let data = try granted.bookmarkData(options: .withSecurityScope)
            UserDefaults.standard.set(data, forKey: Self.bookmarkKey(for: granted))
        } catch {
            return nil
        }

        guard granted.startAccessingSecurityScopedResource() else { return nil }
        activeAccess[granted] = granted
        return granted
    }

    private static func bookmarkKey(for folderURL: URL) -> String {
        bookmarkKeyPrefix + folderURL.standardizedFileURL.path
    }

    private static func declinedKey(for folderURL: URL) -> String {
        declinedKeyPrefix + folderURL.standardizedFileURL.path
    }
}
