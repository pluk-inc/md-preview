//
//  MainSplitViewController.swift
//  md-preview
//

import Cocoa

final class MainSplitViewController: NSSplitViewController {

    private static let didSeedDividerKey = "MainSplitView.didSeedDivider"

    override func viewDidLoad() {
        super.viewDidLoad()

        let sidebar = NSSplitViewItem(sidebarWithViewController: SidebarViewController())
        sidebar.minimumThickness = 180
        sidebar.maximumThickness = 400
        sidebar.canCollapse = true

        let content = NSSplitViewItem(viewController: ContentViewController())
        content.minimumThickness = 420

        addSplitViewItem(sidebar)
        addSplitViewItem(content)

        splitView.autosaveName = "MainSplitView"
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: Self.didSeedDividerKey) {
            splitView.setPosition(240, ofDividerAt: 0)
            defaults.set(true, forKey: Self.didSeedDividerKey)
        }
    }
}
