import AppKit
import AtelierKit
import SwiftUI

/// Handles application-level lifecycle events that SwiftUI scenes don't cover.
final class AppDelegate: NSObject, NSApplicationDelegate {

    var projectStore: ProjectStore?
    var openWindow: OpenWindowAction?

    /// Suppress automatic window creation when clicking the dock icon
    /// with no windows open. The user can open a project explicitly
    /// via File → New Window or File → Open Folder.
    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        false
    }

    /// Right-click dock menu.
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(
            NSMenuItem(
                title: "New Window",
                action: #selector(newWindow),
                keyEquivalent: ""
            )
        )
        return menu
    }

    @objc private func newWindow() {
        guard let projectStore, let openWindow else { return }
        let metadata = try? projectStore.createProject(rootURL: nil)
        if let id = metadata?.id {
            projectStore.registerOpenWindow(id: id)
            openWindow(value: id)
        }
    }
}
