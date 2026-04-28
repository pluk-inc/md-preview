//
//  AppDelegate.swift
//  md-preview
//
//  Created by Fauzaan on 4/28/26.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate, NSToolbarDelegate {

    @IBOutlet var window: NSWindow!

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
        window.toolbarStyle = .unified

        window.makeKeyAndOrderFront(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.flexibleSpace, .toggleSidebar, .sidebarTrackingSeparator]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.toggleSidebar, .sidebarTrackingSeparator, .flexibleSpace, .space]
    }

    func toolbar(_ toolbar: NSToolbar,
                 itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        nil
    }
}
