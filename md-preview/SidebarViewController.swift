//
//  SidebarViewController.swift
//  md-preview
//

import Cocoa

final class SidebarViewController: NSViewController {

    enum Mode: Int {
        case outline = 0
        case files = 1
    }

    var onSelectHeading: ((Int) -> Void)?
    var onSelectFile: ((URL) -> Void)?
    var onModeChanged: ((Mode) -> Void)?

    private var contentContainer: NSView!
    private var scrollView: NSScrollView!
    private var outlineView: NSOutlineView!
    private var projectNavigator: ProjectNavigatorView!
    private var roots: [TOCNode] = []
    private var titleItem: TitleItem?
    private var lastRenderedMarkdown: String?
    private var lastRenderedFileName: String?
    private var loadedFolderURL: URL?
    private var pendingFolderURL: URL?
    private var pendingFileURL: URL?

    private static let modeDefaultsKey = "Sidebar.Mode"

    private(set) var currentMode: Mode = {
        Mode(rawValue: UserDefaults.standard.integer(forKey: SidebarViewController.modeDefaultsKey)) ?? .outline
    }()

    private var titleOffset: Int { titleItem == nil ? 0 : 1 }

    override func loadView() {
        let container = NSView()

        contentContainer = NSView()
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(contentContainer)

        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        contentContainer.addSubview(scrollView)

        outlineView = NSOutlineView()
        outlineView.style = .sourceList
        outlineView.headerView = nil
        outlineView.allowsMultipleSelection = false
        outlineView.allowsEmptySelection = true
        outlineView.floatsGroupRows = false
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.target = self
        outlineView.action = #selector(rowClicked(_:))
        // Don't grab keyboard focus — leave first responder on the document so
        // arrow / Page keys scroll the preview instead of moving the sidebar
        // selection. Click selects rows via target/action, not via focus.
        outlineView.refusesFirstResponder = true

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("title"))
        column.isEditable = false
        column.resizingMask = .autoresizingMask
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column

        scrollView.documentView = outlineView

        projectNavigator = ProjectNavigatorView()
        projectNavigator.translatesAutoresizingMaskIntoConstraints = false
        projectNavigator.onSelectFile = { [weak self] url in
            self?.onSelectFile?(url)
        }
        contentContainer.addSubview(projectNavigator)

        NSLayoutConstraint.activate([
            contentContainer.topAnchor.constraint(equalTo: container.topAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            scrollView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),

            projectNavigator.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            projectNavigator.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            projectNavigator.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            projectNavigator.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
        ])

        view = container
        applyMode()
    }

    func setMode(_ newMode: Mode) {
        guard newMode != currentMode else { return }
        currentMode = newMode
        UserDefaults.standard.set(newMode.rawValue, forKey: Self.modeDefaultsKey)
        if isViewLoaded {
            applyMode()
            if newMode == .files {
                refreshNavigatorIfNeeded()
            }
        }
        onModeChanged?(newMode)
    }

    private func refreshNavigatorIfNeeded() {
        if pendingFolderURL != loadedFolderURL {
            loadedFolderURL = pendingFolderURL
            projectNavigator.setRoot(pendingFolderURL)
        }
        projectNavigator.setCurrentFile(pendingFileURL)
    }

    private func applyMode() {
        switch currentMode {
        case .outline:
            scrollView.isHidden = false
            projectNavigator.isHidden = true
        case .files:
            scrollView.isHidden = true
            projectNavigator.isHidden = false
        }
    }

    func display(markdown: String, fileName: String, fileURL: URL?) {
        loadViewIfNeeded()

        // Defer folder enumeration until the user actually switches to the
        // Project Navigator — saves the disk walk on every TOC-mode open.
        pendingFolderURL = fileURL?.deletingLastPathComponent()
        pendingFileURL = fileURL
        if currentMode == .files {
            refreshNavigatorIfNeeded()
        }

        guard markdown != lastRenderedMarkdown || fileName != lastRenderedFileName else { return }
        lastRenderedMarkdown = markdown
        lastRenderedFileName = fileName
        titleItem = fileName.isEmpty ? nil : TitleItem(title: fileName)
        roots = MarkdownTOC.parse(markdown).map(TOCNode.init)
        outlineView.reloadData()
        for root in roots {
            outlineView.expandItem(root, expandChildren: true)
        }
    }

    @objc private func rowClicked(_ sender: Any?) {
        let row = outlineView.clickedRow
        guard row >= 0, let node = outlineView.item(atRow: row) as? TOCNode else { return }
        onSelectHeading?(node.headingID)
    }
}

private final class TitleItem {
    let title: String
    init(title: String) { self.title = title }
}

final class TOCNode {
    let headingID: Int
    let level: Int
    let title: String
    let children: [TOCNode]

    init(_ item: TOCItem) {
        self.headingID = item.id
        self.level = item.level
        self.title = item.title
        self.children = item.children.map(TOCNode.init)
    }
}

extension SidebarViewController: NSOutlineViewDataSource {

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let node = item as? TOCNode { return node.children.count }
        return roots.count + titleOffset
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let node = item as? TOCNode { return node.children[index] }
        if let titleItem, index == 0 { return titleItem }
        return roots[index - titleOffset]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let node = item as? TOCNode else { return false }
        return !node.children.isEmpty
    }
}

extension SidebarViewController: NSOutlineViewDelegate {

    func outlineView(_ outlineView: NSOutlineView,
                     viewFor tableColumn: NSTableColumn?,
                     item: Any) -> NSView? {
        if let titleItem = item as? TitleItem {
            return titleCell(for: titleItem, in: outlineView)
        }
        guard let node = item as? TOCNode else { return nil }

        let identifier = NSUserInterfaceItemIdentifier("TOCCell")
        let cell: NSTableCellView
        if let recycled = outlineView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
            cell = recycled
        } else {
            cell = NSTableCellView()
            cell.identifier = identifier

            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.lineBreakMode = .byTruncatingTail
            textField.cell?.usesSingleLineMode = true
            textField.cell?.truncatesLastVisibleLine = true
            textField.maximumNumberOfLines = 1
            textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
            cell.addSubview(textField)
            cell.textField = textField

            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        }

        cell.textField?.stringValue = node.title
        return cell
    }

    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        return item is TOCNode
    }

    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        return 30
    }

    private func titleCell(for titleItem: TitleItem, in outlineView: NSOutlineView) -> NSView {
        let identifier = NSUserInterfaceItemIdentifier("TitleCell")
        let cell: NSTableCellView
        if let recycled = outlineView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
            cell = recycled
        } else {
            cell = NSTableCellView()
            cell.identifier = identifier

            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
            textField.textColor = .secondaryLabelColor
            textField.lineBreakMode = .byTruncatingMiddle
            textField.cell?.usesSingleLineMode = true
            textField.maximumNumberOfLines = 1
            cell.addSubview(textField)
            cell.textField = textField

            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor),
                textField.topAnchor.constraint(equalTo: cell.topAnchor, constant: 8),
                textField.bottomAnchor.constraint(equalTo: cell.bottomAnchor, constant: -4)
            ])
        }
        cell.textField?.stringValue = titleItem.title
        return cell
    }
}

// MARK: - Project Navigator

private final class FileNode {
    static let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mkd", "mdwn"]

    let url: URL
    let isDirectory: Bool
    private var loadedChildren: [FileNode]?

    init(url: URL, isDirectory: Bool) {
        self.url = url
        self.isDirectory = isDirectory
    }

    var displayName: String { url.lastPathComponent }

    func children() -> [FileNode] {
        if let cached = loadedChildren { return cached }
        guard isDirectory else {
            loadedChildren = []
            return []
        }
        let entries = (try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles])) ?? []
        let nodes: [FileNode] = entries.compactMap { entry in
            let isDir = (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if isDir { return FileNode(url: entry, isDirectory: true) }
            guard FileNode.markdownExtensions.contains(entry.pathExtension.lowercased()) else { return nil }
            return FileNode(url: entry, isDirectory: false)
        }
        let sorted = nodes.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
            return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
        }
        loadedChildren = sorted
        return sorted
    }
}

final class ProjectNavigatorView: NSView {

    var onSelectFile: ((URL) -> Void)?

    private let scrollView = NSScrollView()
    private let outlineView = NSOutlineView()
    private var rootNode: FileNode?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setUp()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    private func setUp() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        addSubview(scrollView)

        outlineView.style = .sourceList
        outlineView.headerView = nil
        outlineView.allowsMultipleSelection = false
        outlineView.allowsEmptySelection = true
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.target = self
        outlineView.action = #selector(rowClicked)
        outlineView.indentationPerLevel = 14
        outlineView.refusesFirstResponder = true

        let contextMenu = NSMenu()
        contextMenu.delegate = self
        outlineView.menu = contextMenu

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("file"))
        column.isEditable = false
        column.resizingMask = .autoresizingMask
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column

        scrollView.documentView = outlineView

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    func setRoot(_ url: URL?) {
        rootNode = url.map { FileNode(url: $0, isDirectory: true) }
        outlineView.reloadData()
        if let rootNode {
            outlineView.expandItem(rootNode)
        }
    }

    func setCurrentFile(_ url: URL?) {
        guard let url, let rootNode else {
            outlineView.deselectAll(nil)
            return
        }
        let target = url.standardizedFileURL
        var path: [FileNode] = []
        guard collectPath(to: target, from: rootNode, into: &path) else {
            outlineView.deselectAll(nil)
            return
        }
        for ancestor in path.dropLast() {
            outlineView.expandItem(ancestor)
        }
        if let leaf = path.last {
            let row = outlineView.row(forItem: leaf)
            if row >= 0 {
                outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                outlineView.scrollRowToVisible(row)
            }
        }
    }

    private func collectPath(to targetURL: URL,
                             from root: FileNode,
                             into path: inout [FileNode]) -> Bool {
        // Skip whole subtrees that can't contain the target — avoids enumerating
        // sibling folders just to highlight one row.
        let rootPath = root.url.standardizedFileURL.path
        let target = targetURL.path
        guard target == rootPath || target.hasPrefix(rootPath + "/") else { return false }

        for child in root.children() {
            if child.url.standardizedFileURL == targetURL {
                path.append(child)
                return true
            }
            if child.isDirectory {
                path.append(child)
                if collectPath(to: targetURL, from: child, into: &path) { return true }
                path.removeLast()
            }
        }
        return false
    }

    @objc private func rowClicked() {
        let row = outlineView.clickedRow
        guard row >= 0, let node = outlineView.item(atRow: row) as? FileNode else { return }
        if !node.isDirectory {
            onSelectFile?(node.url)
        }
    }

    @objc private func showInFinder(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    @objc private func openInNewWindow(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL,
              let appDelegate = NSApp.delegate as? AppDelegate else { return }
        appDelegate.openInNewWindow(url)
    }

    @objc private func copyPath(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(url.path, forType: .string)
    }

    @objc private func copyContents(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        Task { @concurrent in
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { return }
            await MainActor.run {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(text, forType: .string)
            }
        }
    }
}

extension ProjectNavigatorView: NSMenuDelegate {

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let row = outlineView.clickedRow
        guard row >= 0, let node = outlineView.item(atRow: row) as? FileNode else { return }
        let url = node.url

        menu.addItem(makeMenuItem(title: "Show in Finder",
                                  symbol: "folder",
                                  action: #selector(showInFinder(_:)),
                                  url: url))

        if !node.isDirectory {
            menu.addItem(.separator())
            menu.addItem(makeMenuItem(title: "Open in New Window",
                                      symbol: "macwindow.badge.plus",
                                      action: #selector(openInNewWindow(_:)),
                                      url: url))
            if let appDelegate = NSApp.delegate as? AppDelegate {
                for item in appDelegate.contextMenuEditorItems(for: url) {
                    menu.addItem(item)
                }
            }
            menu.addItem(.separator())
            menu.addItem(makeMenuItem(title: "Copy",
                                      symbol: "document.on.clipboard",
                                      action: #selector(copyContents(_:)),
                                      url: url))
        } else {
            menu.addItem(.separator())
        }

        menu.addItem(makeMenuItem(title: "Copy Path",
                                  symbol: "document.on.document",
                                  action: #selector(copyPath(_:)),
                                  url: url))
    }

    private func makeMenuItem(title: String,
                              symbol: String,
                              action: Selector,
                              url: URL) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.representedObject = url
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        return item
    }
}

extension ProjectNavigatorView: NSOutlineViewDataSource {

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let node = item as? FileNode { return node.children().count }
        return rootNode == nil ? 0 : 1
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let node = item as? FileNode { return node.children()[index] }
        return rootNode!
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let node = item as? FileNode else { return false }
        return node.isDirectory && !node.children().isEmpty
    }
}

extension ProjectNavigatorView: NSOutlineViewDelegate {

    func outlineView(_ outlineView: NSOutlineView,
                     viewFor tableColumn: NSTableColumn?,
                     item: Any) -> NSView? {
        guard let node = item as? FileNode else { return nil }
        let identifier = NSUserInterfaceItemIdentifier("FileCell")
        let cell: NSTableCellView
        if let recycled = outlineView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
            cell = recycled
        } else {
            cell = NSTableCellView()
            cell.identifier = identifier

            let imageView = NSImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.imageScaling = .scaleProportionallyDown
            cell.addSubview(imageView)
            cell.imageView = imageView

            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.lineBreakMode = .byTruncatingTail
            textField.cell?.usesSingleLineMode = true
            textField.maximumNumberOfLines = 1
            cell.addSubview(textField)
            cell.textField = textField

            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 16),
                imageView.heightAnchor.constraint(equalToConstant: 16),
                textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -6),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        }

        cell.textField?.stringValue = node.displayName
        let icon = NSWorkspace.shared.icon(forFile: node.url.path)
        icon.size = NSSize(width: 16, height: 16)
        cell.imageView?.image = icon
        return cell
    }

    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        return 24
    }
}
