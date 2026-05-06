//
//  AppDelegate.swift
//  md-preview
//
//  Created by Fauzaan on 4/28/26.
//

import Cocoa
import Sparkle
import UniformTypeIdentifiers

extension NSToolbarItem.Identifier {
    static let openWith = NSToolbarItem.Identifier("OpenWith")
    static let inspector = NSToolbarItem.Identifier("Inspector")
    static let share = NSToolbarItem.Identifier("Share")
    static let search = NSToolbarItem.Identifier("Search")
}

@main
class AppDelegate: NSObject, NSApplicationDelegate, NSToolbarDelegate, NSSharingServicePickerToolbarItemDelegate, NSSearchFieldDelegate {

    @IBOutlet var window: NSWindow!

    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    private var pendingLaunchURL: URL?
    private var hasLaunched = false
    private var currentFileURL: URL?
    private var currentMarkdown: String?
    private var fileWatcher: FileWatcher?
    private var isInspectorToggleSelected = false
    private weak var openWithItem: NSMenuToolbarItem?
    private weak var inspectorItem: NSToolbarItem?
    private weak var inspectorButton: NSButton?
    private weak var searchField: NSSearchField?
    private var accessBanner: MissingFolderAccessBanner?
    private var accessBannerAccessory: NSTitlebarAccessoryViewController?
    private var findBar: FindBar?
    private var findBarAccessory: NSTitlebarAccessoryViewController?
    private var searchMode: SearchMode = .contains
    private var pendingFindWork: DispatchWorkItem?
    private static let findDebounceDelay: TimeInterval = 0.10

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        if hasLaunched {
            present(url: url)
        } else {
            pendingLaunchURL = url
        }
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        window.styleMask.insert(.fullSizeContentView)
        window.contentViewController = MainSplitViewController()
        window.setContentSize(NSSize(width: 1100, height: 720))
        window.center()
        window.setFrameAutosaveName("MainWindow")

        let toolbar = NSToolbar(identifier: "MainToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        window.toolbar = toolbar
        window.toolbarStyle = .automatic

        installFindBar()
        installAccessBanner()

        hasLaunched = true

        if let url = pendingLaunchURL {
            pendingLaunchURL = nil
            present(url: url)
            return
        }

        let panel = makeOpenPanel()
        guard panel.runModal() == .OK, let url = panel.url else {
            NSApp.terminate(nil)
            return
        }
        present(url: url)
    }

    private func present(url: URL) {
        currentFileURL = url
        currentMarkdown = nil
        window.title = url.lastPathComponent
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
        refreshOpenWithItem()
        loadFile(at: url)
        startWatching(url)
        offerToBecomeDefaultHandlerIfNeeded()
    }

    private func startWatching(_ url: URL) {
        fileWatcher?.cancel()
        fileWatcher = FileWatcher(url: url) { [weak self] in
            guard let self, self.currentFileURL == url else { return }
            self.loadFile(at: url, silentOnFailure: true)
        }
    }

    private static let didOfferDefaultHandlerKey = "MarkdownPreview.didOfferAsDefaultHandler"

    private func offerToBecomeDefaultHandlerIfNeeded() {
        let key = Self.didOfferDefaultHandlerKey
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        guard let markdownType = UTType("net.daringfireball.markdown")
                ?? UTType(filenameExtension: "md") else { return }

        let currentDefaultID = NSWorkspace.shared.urlForApplication(toOpen: markdownType)
            .flatMap { Bundle(url: $0)?.bundleIdentifier }
        if currentDefaultID == Bundle.main.bundleIdentifier {
            UserDefaults.standard.set(true, forKey: key)
            return
        }

        UserDefaults.standard.set(true, forKey: key)
        Task {
            try? await NSWorkspace.shared.setDefaultApplication(
                at: Bundle.main.bundleURL,
                toOpen: markdownType
            )
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            promptForFileAndPresent()
        }
        return true
    }

    private func promptForFileAndPresent() {
        let panel = makeOpenPanel()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        present(url: url)
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            .flexibleSpace,
            .toggleSidebar,
            .sidebarTrackingSeparator,
            .openWith,
            .flexibleSpace,
            .inspector,
            .share,
            .search
        ]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            .toggleSidebar,
            .sidebarTrackingSeparator,
            .flexibleSpace,
            .space,
            .openWith,
            .inspector,
            .share,
            .search
        ]
    }

    func toolbar(_ toolbar: NSToolbar,
                 itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {
        case .openWith: return makeOpenWithItem()
        case .inspector: return makeInspectorItem()
        case .share: return makeShareItem()
        case .search: return makeSearchItem()
        default: return nil
        }
    }

    private func makeInspectorItem() -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: .inspector)
        item.label = "Inspector"
        item.paletteLabel = "Inspector"
        item.toolTip = "Show or hide inspector"

        let button = NSButton(image: inspectorImage(),
                              target: self,
                              action: #selector(toggleInspectorAction(_:)))
        button.setButtonType(.pushOnPushOff)
        button.toolTip = item.toolTip
        button.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(button)
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 2),
            button.topAnchor.constraint(equalTo: container.topAnchor),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -2),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            button.heightAnchor.constraint(equalToConstant: 32),
            container.widthAnchor.constraint(equalToConstant: 36),
            container.heightAnchor.constraint(equalToConstant: 32)
        ])

        item.view = container
        inspectorButton = button
        inspectorItem = item
        refreshInspectorToggleItem()
        return item
    }

    private func makeShareItem() -> NSToolbarItem {
        let item = NSSharingServicePickerToolbarItem(itemIdentifier: .share)
        item.label = "Share"
        item.paletteLabel = "Share"
        item.toolTip = "Share document"
        item.delegate = self
        return item
    }

    private func inspectorImage() -> NSImage {
        let image = NSImage(systemSymbolName: "info",
                            accessibilityDescription: "Inspector") ?? NSImage()
        image.isTemplate = true
        return image
    }

    @objc private func toggleInspectorAction(_ sender: Any) {
        let isVisible = (window.contentViewController as? MainSplitViewController)?
            .toggleInspector() ?? false
        setInspectorToggleSelected(isVisible)
    }

    private func refreshInspectorToggleItem() {
        let isVisible = (window.contentViewController as? MainSplitViewController)?
            .isInspectorVisible ?? false
        setInspectorToggleSelected(isVisible)
    }

    private func setInspectorToggleSelected(_ isSelected: Bool) {
        isInspectorToggleSelected = isSelected
        inspectorButton?.state = isSelected ? .on : .off
    }

    func items(for pickerToolbarItem: NSSharingServicePickerToolbarItem) -> [Any] {
        guard let currentMarkdown else { return [] }
        return [currentMarkdown]
    }

    private func makeSearchItem() -> NSToolbarItem {
        let item = NSSearchToolbarItem(itemIdentifier: .search)
        item.label = "Search"
        item.toolTip = "Search in document"
        item.preferredWidthForSearchField = 320
        item.searchField.placeholderString = "Search in Document"
        item.searchField.sendsSearchStringImmediately = true
        item.searchField.target = self
        item.searchField.action = #selector(searchFieldDidChange(_:))
        item.searchField.delegate = self
        searchField = item.searchField
        return item
    }

    @objc private func searchFieldDidChange(_ sender: NSSearchField) {
        // Coalesce per-keystroke finds — running the full DOM rewrite + JS
        // round-trip on every char is the dominant stall source on big docs.
        // Empty queries (e.g. user cleared the field) bypass the debounce so
        // the highlight teardown happens immediately.
        let query = sender.stringValue
        pendingFindWork?.cancel()
        if query.isEmpty {
            pendingFindWork = nil
            runFind(query: query)
            return
        }
        let work = DispatchWorkItem { [weak self] in
            self?.runFind(query: query)
        }
        pendingFindWork = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.findDebounceDelay, execute: work
        )
    }

    private func runFind(query: String, backwards: Bool = false) {
        // Explicit nav (Enter / prev / next / mode change) flushes any pending
        // debounce so the user navigates the freshest results.
        pendingFindWork?.cancel()
        pendingFindWork = nil
        (window.contentViewController as? MainSplitViewController)?
            .find(query, backwards: backwards, mode: searchMode) { [weak self] result in
                self?.applyFindResult(result, query: query)
            }
    }

    func control(_ control: NSControl,
                 textView: NSTextView,
                 doCommandBy commandSelector: Selector) -> Bool {
        guard control === searchField,
              commandSelector == #selector(NSResponder.insertNewline(_:)) else {
            return false
        }
        let backwards = NSEvent.modifierFlags.contains(.shift)
        findFromToolbar(backwards: backwards)
        return true
    }

    private func applyFindResult(_ result: FindResult, query: String) {
        if query.isEmpty {
            setFindBarVisible(false)
            return
        }
        findBar?.update(matchCount: result.total, currentIndex: result.index)
        setFindBarVisible(true)
    }

    private func setFindBarVisible(_ visible: Bool) {
        guard let accessory = findBarAccessory, accessory.isHidden == visible else { return }
        accessory.isHidden = !visible
    }

    private func installFindBar() {
        let bar = FindBar(
            frame: NSRect(x: 0, y: 0, width: 600, height: FindBar.preferredHeight)
        )
        bar.autoresizingMask = [.width]
        bar.onPrevious = { [weak self] in self?.findFromToolbar(backwards: true) }
        bar.onNext = { [weak self] in self?.findFromToolbar(backwards: false) }
        bar.onDone = { [weak self] in self?.dismissFindBar() }
        bar.onModeChanged = { [weak self] mode in self?.searchModeDidChange(mode) }

        // Default `.automatic` — `.hard` deadlocks initial layout against our
        // nested non-scrolling WKWebView. Find bar's own bottom rule gives
        // the dividing line either way.
        self.findBar = bar
        self.findBarAccessory = addBottomTitlebarAccessory(bar)
    }

    private func dismissFindBar() {
        searchField?.stringValue = ""
        if let editor = searchField?.currentEditor(),
           window.firstResponder === editor {
            window.makeFirstResponder(nil)
        }
        runFind(query: "")
    }

    @IBAction func performFindPanelAction(_ sender: Any?) {
        handleFindAction(sender)
    }

    @IBAction func performTextFinderAction(_ sender: Any?) {
        handleFindAction(sender)
    }

    private func handleFindAction(_ sender: Any?) {
        let tag = (sender as? NSValidatedUserInterfaceItem)?.tag ?? 1
        switch tag {
        case NSTextFinder.Action.nextMatch.rawValue:
            findFromToolbar(backwards: false)
        case NSTextFinder.Action.previousMatch.rawValue:
            findFromToolbar(backwards: true)
        default:
            focusToolbarSearch()
        }
    }

    private func findFromToolbar(backwards: Bool) {
        let query = searchField?.stringValue
            ?? NSPasteboard(name: .find).string(forType: .string)
            ?? ""
        guard !query.isEmpty else {
            focusToolbarSearch()
            return
        }
        runFind(query: query, backwards: backwards)
    }

    private func searchModeDidChange(_ mode: SearchMode) {
        guard mode != searchMode else { return }
        searchMode = mode
        guard findBarAccessory?.isHidden == false,
              let query = searchField?.stringValue, !query.isEmpty else { return }
        runFind(query: query)
    }

    private func focusToolbarSearch() {
        guard let searchField else { return }
        window.makeFirstResponder(searchField)
        searchField.selectText(nil)
    }

    // MARK: - Open With

    private static let markdownFileExtensions = ["md", "markdown", "mdown", "txt"]
    private static let markdownDocTypeExtensions: Set<String> = ["md", "markdown", "mdown"]
    private static let strongMarkdownUTIs: Set<String> = ["net.daringfireball.markdown"]
    private static let plainTextUTIs: Set<String> = [
        "public.plain-text", "public.text",
        "public.utf8-plain-text", "public.utf16-plain-text"
    ]
    private static let textyUTIs: Set<String> = plainTextUTIs.union(strongMarkdownUTIs)
    private static let defaultEditorBundleIDKey = "MarkdownPreview.defaultEditorBundleID"
    private static let defaultEditorURLKey = "MarkdownPreview.defaultEditorURL"
    private static let editorBundleIDPriority = [
        "com.microsoft.VSCode",
        "com.todesktop.230313mzl4w4u92",
        "dev.zed.Zed",
        "com.sublimetext.4",
        "com.sublimetext.3",
        "com.barebones.bbedit",
        "com.panic.Nova",
        "com.coteditor.CotEditor",
        "com.apple.TextEdit",
        "com.apple.dt.Xcode",
        "com.macromates.TextMate",
        "org.vim.MacVim"
    ]

    private func makeOpenWithItem() -> NSToolbarItem {
        let item = NSMenuToolbarItem(itemIdentifier: .openWith)
        item.label = "Open With"
        item.paletteLabel = "Open With"
        item.toolTip = "Open in another editor"
        item.target = self
        item.action = #selector(openWithPrimaryAction(_:))
        item.showsIndicator = true
        openWithItem = item
        refreshOpenWithItem()
        return item
    }

    private struct EditorCandidate {
        let url: URL
        let bundleID: String?
    }

    private func refreshOpenWithItem() {
        let candidates = currentFileURL.map { editorCandidates(for: $0) } ?? []
        let resolvedDefault = resolveDefaultEditor(among: candidates)
        let openInTitle = resolvedDefault.map { "Open in \(displayName(for: $0.url))" }
        openWithItem?.label = openInTitle ?? "Open With"
        openWithItem?.image = openWithImage(for: resolvedDefault?.url)
        openWithItem?.toolTip = openInTitle ?? "Open in another editor"
        openWithItem?.menu = buildOpenWithMenu(candidates: candidates,
                                               defaultEditor: resolvedDefault)
    }

    private func openWithImage(for url: URL?) -> NSImage {
        if let url {
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            icon.size = NSSize(width: 20, height: 20)
            return icon
        }
        return NSImage(systemSymbolName: "highlighter",
                       accessibilityDescription: "Open With") ?? NSImage()
    }

    @objc private func openWithPrimaryAction(_ sender: Any?) {
        guard let fileURL = currentFileURL else { return }
        let candidates = editorCandidates(for: fileURL)
        if let editor = resolveDefaultEditor(among: candidates) {
            launch(fileURL, with: editor.url)
        }
    }

    private func editorCandidates(for fileURL: URL) -> [EditorCandidate] {
        let myBundleID = Bundle.main.bundleIdentifier
        // Every URL Launch Services has registered for our bundle id — covers stale DerivedData /
        // archive copies the sandbox can't introspect by reading their Info.plist.
        var selfURLs: Set<URL> = [canonicalAppURL(Bundle.main.bundleURL)]
        if let myBundleID {
            for url in NSWorkspace.shared.urlsForApplications(withBundleIdentifier: myBundleID) {
                selfURLs.insert(canonicalAppURL(url))
            }
        }

        return NSWorkspace.shared.urlsForApplications(toOpen: fileURL).compactMap { appURL in
            if selfURLs.contains(canonicalAppURL(appURL)) { return nil }
            let plist = infoPlist(at: appURL)
            let bundleID = (plist?["CFBundleIdentifier"] as? String)
                ?? Bundle(url: appURL)?.bundleIdentifier
            guard canEditMarkdown(plist: plist) else { return nil }
            return EditorCandidate(url: appURL, bundleID: bundleID)
        }
    }

    private func resolveDefaultEditor(among candidates: [EditorCandidate]) -> EditorCandidate? {
        let myBundleID = Bundle.main.bundleIdentifier
        if let persistedID = UserDefaults.standard.string(forKey: Self.defaultEditorBundleIDKey),
           persistedID != myBundleID {
            if let match = candidates.first(where: { $0.bundleID == persistedID }) {
                return match
            }
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: persistedID) {
                return EditorCandidate(url: url, bundleID: persistedID)
            }
        }

        if let persistedPath = UserDefaults.standard.string(forKey: Self.defaultEditorURLKey) {
            let persistedURL = canonicalAppURL(URL(fileURLWithPath: persistedPath))
            if let match = candidates.first(where: { sameApplication($0.url, persistedURL) }) {
                return match
            }
        }

        for preferred in Self.editorBundleIDPriority {
            if let match = candidates.first(where: { $0.bundleID == preferred }) {
                return match
            }
        }
        return candidates.first
    }

    private func buildOpenWithMenu(candidates: [EditorCandidate],
                                   defaultEditor: EditorCandidate?) -> NSMenu {
        let menu = NSMenu()

        guard currentFileURL != nil else {
            menu.addItem(disabledItem("No document open"))
            return menu
        }
        guard !candidates.isEmpty else {
            menu.addItem(disabledItem("No editors available"))
            return menu
        }

        let header = NSMenuItem()
        header.title = "Open with…"
        header.isEnabled = false
        menu.addItem(header)

        for candidate in candidates {
            let item = NSMenuItem(
                title: displayName(for: candidate.url),
                action: #selector(pickEditor(_:)),
                keyEquivalent: ""
            )
            let icon = NSWorkspace.shared.icon(forFile: candidate.url.path)
            icon.size = NSSize(width: 16, height: 16)
            item.image = icon
            item.target = self
            item.representedObject = candidate
            if let defaultEditor, sameEditor(candidate, defaultEditor) {
                item.state = .on
            }
            menu.addItem(item)
        }
        return menu
    }

    private func displayName(for appURL: URL) -> String {
        FileManager.default.displayName(atPath: appURL.path)
            .replacingOccurrences(of: ".app", with: "")
    }

    private func sameEditor(_ lhs: EditorCandidate, _ rhs: EditorCandidate) -> Bool {
        if let leftID = lhs.bundleID, let rightID = rhs.bundleID {
            return leftID == rightID
        }
        return sameApplication(lhs.url, rhs.url)
    }

    private func sameApplication(_ lhs: URL, _ rhs: URL) -> Bool {
        canonicalAppURL(lhs) == canonicalAppURL(rhs)
    }

    private func canonicalAppURL(_ url: URL) -> URL {
        url.resolvingSymlinksInPath().standardizedFileURL
    }

    private func infoPlist(at appURL: URL) -> [String: Any]? {
        let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data,
                                                                       options: [],
                                                                       format: nil) as? [String: Any] else {
            return Bundle(url: appURL)?.infoDictionary
        }
        return plist
    }

    private func canEditMarkdown(plist: [String: Any]?) -> Bool {
        guard let docTypes = plist?["CFBundleDocumentTypes"] as? [[String: Any]] else {
            return true
        }

        var matchedAsEditor = false
        var matchedAsViewer = false

        for docType in docTypes {
            let utis = Set((docType["LSItemContentTypes"] as? [String]) ?? [])
            let extensions = Set(((docType["CFBundleTypeExtensions"] as? [String]) ?? [])
                .map { $0.lowercased() })
            let rank = (docType["LSHandlerRank"] as? String) ?? "Default"

            let hasMarkdownUTI = !Self.strongMarkdownUTIs.isDisjoint(with: utis)
            let hasMarkdownExtension = !Self.markdownDocTypeExtensions.isDisjoint(with: extensions)
            // A generic plain-text claim only counts as "real text editor" when the entry's UTI
            // list is purely text-flavored and isn't ranked Alternate. That filters Postico
            // (Alternate) and Numbers (bundles public.plain-text with CSV/TSV import UTIs).
            let isPureTextEntry = !utis.isEmpty && utis.isSubset(of: Self.textyUTIs)
            let isPlainTextEditor = isPureTextEntry && rank != "Alternate"

            guard hasMarkdownUTI || hasMarkdownExtension || isPlainTextEditor else { continue }

            let role = (docType["CFBundleTypeRole"] as? String) ?? "Editor"
            switch role {
            case "Viewer", "QLGenerator": matchedAsViewer = true
            default: matchedAsEditor = true
            }
        }

        if matchedAsEditor { return true }
        if matchedAsViewer { return false }
        return false
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    @objc private func pickEditor(_ sender: NSMenuItem) {
        guard let candidate = sender.representedObject as? EditorCandidate,
              let fileURL = currentFileURL else { return }
        if let bundleID = candidate.bundleID {
            UserDefaults.standard.set(bundleID, forKey: Self.defaultEditorBundleIDKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.defaultEditorBundleIDKey)
        }
        UserDefaults.standard.set(candidate.url.path, forKey: Self.defaultEditorURLKey)
        refreshOpenWithItem()
        launch(fileURL, with: candidate.url)
    }

    private func launch(_ fileURL: URL, with appURL: URL) {
        NSWorkspace.shared.open(
            [fileURL],
            withApplicationAt: appURL,
            configuration: NSWorkspace.OpenConfiguration()
        ) { _, _ in }
    }

    @IBAction func checkForUpdates(_ sender: Any?) {
        updaterController.updater.checkForUpdates()
    }

    @IBAction func openDocument(_ sender: Any?) {
        guard window.isVisible else {
            promptForFileAndPresent()
            return
        }
        let panel = makeOpenPanel()
        panel.beginSheetModal(for: window) { [weak self] response in
            guard let self, response == .OK, let url = panel.url else { return }
            self.present(url: url)
        }
    }

    private func makeOpenPanel() -> NSOpenPanel {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Choose a Markdown file"
        panel.allowedContentTypes = Self.markdownFileExtensions
            .compactMap { UTType(filenameExtension: $0) }
        return panel
    }

    private func loadFile(at url: URL, silentOnFailure: Bool = false) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result { try String(contentsOf: url, encoding: .utf8) }
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let text):
                    self.currentMarkdown = text
                    self.renderCurrentDocument(text: text, fileURL: url)
                case .failure(let error):
                    if !silentOnFailure {
                        NSAlert(error: error).beginSheetModal(for: self.window)
                    }
                }
            }
        }
    }

    private func renderCurrentDocument(text: String, fileURL: URL) {
        let assetBase = SandboxAccessManager.shared.currentAccessURL(forParentOf: fileURL)

        let needsBanner = assetBase == nil
            && MarkdownAssetScanner.hasRelativeLocalRefs(text)
        updateAccessBanner(visible: needsBanner,
                           folderName: fileURL.deletingLastPathComponent().lastPathComponent)

        (window.contentViewController as? MainSplitViewController)?
            .display(markdown: text,
                     fileName: fileURL.lastPathComponent,
                     url: fileURL,
                     assetBaseURL: assetBase)
    }

    private func installAccessBanner() {
        let banner = MissingFolderAccessBanner(
            frame: NSRect(x: 0,
                          y: 0,
                          width: 600,
                          height: MissingFolderAccessBanner.preferredHeight))
        banner.autoresizingMask = [.width]
        banner.onAllow = { [weak self] in self?.grantAccessForCurrentDocument() }

        self.accessBanner = banner
        self.accessBannerAccessory = addBottomTitlebarAccessory(banner)
    }

    private func addBottomTitlebarAccessory(_ view: NSView) -> NSTitlebarAccessoryViewController {
        let accessory = NSTitlebarAccessoryViewController()
        accessory.layoutAttribute = .bottom
        accessory.view = view
        accessory.isHidden = true
        window.addTitlebarAccessoryViewController(accessory)
        return accessory
    }

    private func updateAccessBanner(visible: Bool, folderName: String) {
        guard let accessory = accessBannerAccessory, let banner = accessBanner else { return }
        if visible {
            banner.update(folderName: folderName)
        }
        if accessory.isHidden == visible {
            accessory.isHidden = !visible
        }
    }

    private func grantAccessForCurrentDocument() {
        guard let url = currentFileURL, let text = currentMarkdown else { return }
        guard SandboxAccessManager.shared.requestAccess(forParentOf: url) != nil else {
            // User cancelled the panel — leave the banner up so they can retry.
            return
        }
        renderCurrentDocument(text: text, fileURL: url)
    }
}

private final class FileWatcher {
    private let url: URL
    private let onChange: () -> Void
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var debounce: DispatchWorkItem?

    init(url: URL, onChange: @escaping () -> Void) {
        self.url = url
        self.onChange = onChange
        open()
    }

    private func open() {
        let fd = Darwin.open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }
        fileDescriptor = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .delete, .rename, .revoke],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            guard let self, let source = self.source else { return }
            let event = source.data
            self.scheduleChange()
            // Atomic-rename saves (Vim, VS Code, etc.) replace the inode;
            // re-open the watcher against the path so we keep tracking.
            if !event.intersection([.delete, .rename, .revoke]).isEmpty {
                self.reopen()
            }
        }
        source.setCancelHandler { [weak self] in
            guard let self else { return }
            if self.fileDescriptor >= 0 {
                Darwin.close(self.fileDescriptor)
                self.fileDescriptor = -1
            }
        }
        self.source = source
        source.resume()
    }

    private func reopen() {
        source?.cancel()
        source = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.open()
        }
    }

    private func scheduleChange() {
        debounce?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.onChange() }
        debounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: work)
    }

    func cancel() {
        debounce?.cancel()
        source?.cancel()
        source = nil
    }
}
