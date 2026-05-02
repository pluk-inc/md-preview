//
//  SandboxAccessManager.swift
//  md-preview
//

import AppKit
import CryptoKit
import Foundation

@MainActor
final class SandboxAccessManager {

    static let shared = SandboxAccessManager()

    private static let bookmarkKeyPrefix = "MarkdownPreview.folderBookmark."
    private static let declinedKeyPrefix = "MarkdownPreview.folderDeclined."

    // Folder URL → started security-scoped extension.
    private var activeAccess: [URL: URL] = [:]

    private init() {}

    /// Returns access to the parent folder of `fileURL` if it's already active
    /// or restorable from a saved bookmark. Never prompts the user.
    func currentAccessURL(forParentOf fileURL: URL) -> URL? {
        let parent = fileURL.deletingLastPathComponent()
        if let active = activeAccess[parent] {
            return active
        }
        return restoreAccess(for: parent)
    }

    /// Whether the user has previously declined access to this folder. The
    /// banner respects this so we don't keep nagging.
    func hasDeclined(forParentOf fileURL: URL) -> Bool {
        let parent = fileURL.deletingLastPathComponent()
        return UserDefaults.standard.bool(forKey: Self.declinedKey(for: parent))
    }

    /// Mark the parent folder as declined. Clears any prior bookmark too so a
    /// future grant request starts from a clean slate.
    func markDeclined(forParentOf fileURL: URL) {
        let parent = fileURL.deletingLastPathComponent()
        UserDefaults.standard.set(true, forKey: Self.declinedKey(for: parent))
    }

    /// Prompt the user (Powerbox) for access to the parent folder. Returns the
    /// granted URL or `nil` if the user cancelled.
    @discardableResult
    func requestAccess(forParentOf fileURL: URL) -> URL? {
        let parent = fileURL.deletingLastPathComponent()
        if let active = activeAccess[parent] {
            return active
        }
        if let restored = restoreAccess(for: parent) {
            return restored
        }
        if let granted = promptForAccess(to: parent) {
            // Successful grant clears any old "declined" sticky.
            UserDefaults.standard.removeObject(forKey: Self.declinedKey(for: parent))
            return granted
        }
        return nil
    }

    func releaseAllAccess() {
        for url in activeAccess.values {
            url.stopAccessingSecurityScopedResource()
        }
        activeAccess.removeAll()
    }

    func releaseAccess(for folderURL: URL) {
        guard let url = activeAccess.removeValue(forKey: folderURL) else { return }
        url.stopAccessingSecurityScopedResource()
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

        if isStale {
            if let refreshed = try? resolved.bookmarkData(options: .withSecurityScope) {
                UserDefaults.standard.set(refreshed, forKey: key)
            }
        }

        activeAccess[folderURL] = resolved
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

        guard panel.runModal() == .OK, let granted = panel.url else {
            return nil
        }

        do {
            let data = try granted.bookmarkData(options: .withSecurityScope)
            UserDefaults.standard.set(data, forKey: Self.bookmarkKey(for: granted))
        } catch {
            return nil
        }

        guard granted.startAccessingSecurityScopedResource() else { return nil }
        activeAccess[granted] = granted
        // Also key by the requested folder so a later identical lookup hits the cache,
        // even if the user picked an ancestor of the requested folder.
        if granted != folderURL {
            activeAccess[folderURL] = granted
        }
        return granted
    }

    private static func bookmarkKey(for folderURL: URL) -> String {
        bookmarkKeyPrefix + digest(folderURL.standardizedFileURL.path)
    }

    private static func declinedKey(for folderURL: URL) -> String {
        declinedKeyPrefix + digest(folderURL.standardizedFileURL.path)
    }

    private static func digest(_ string: String) -> String {
        let data = Data(string.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
