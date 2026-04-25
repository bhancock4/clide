import AppKit
import SwiftTerm

@main
enum CLIDEEntry {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate = CLIDEAppDelegate()
        app.delegate = delegate
        app.run()
    }
}

class CLIDEAppDelegate: NSObject, NSApplicationDelegate {
    var windowController: MainWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppIcon.setAsAppIcon()
        let settings = AppSettings.load()
        windowController = MainWindowController(settings: settings)
        setupMenus()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        windowController.manager.saveSession()
    }

    private func setupMenus() {
        let mainMenu = NSMenu()

        // App menu
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Settings...", action: #selector(openSettings), keyEquivalent: ",").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit CLIDE", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // File menu
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "New Terminal", action: #selector(newTerminal), keyEquivalent: "n").target = self
        let newSplitItem = NSMenuItem(title: "New Split Terminal", action: #selector(newSplitTerminal), keyEquivalent: "N")
        newSplitItem.keyEquivalentModifierMask = [.command, .shift]
        newSplitItem.target = self
        fileMenu.addItem(newSplitItem)
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: "Close Tab", action: #selector(closeTab), keyEquivalent: "w").target = self
        let fileMenuItem = NSMenuItem()
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        // View menu
        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(withTitle: "Toggle Split", action: #selector(toggleSplit), keyEquivalent: "\\").target = self

        viewMenu.addItem(.separator())

        let prevTab = NSMenuItem(title: "Previous Tab", action: #selector(prevTabAction), keyEquivalent: String(UnicodeScalar(NSLeftArrowFunctionKey)!))
        prevTab.keyEquivalentModifierMask = [.command, .shift]
        prevTab.target = self
        viewMenu.addItem(prevTab)

        let nextTab = NSMenuItem(title: "Next Tab", action: #selector(nextTabAction), keyEquivalent: String(UnicodeScalar(NSRightArrowFunctionKey)!))
        nextTab.keyEquivalentModifierMask = [.command, .shift]
        nextTab.target = self
        viewMenu.addItem(nextTab)

        let viewMenuItem = NSMenuItem()
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        NSApp.mainMenu = mainMenu
    }

    // MARK: - Menu Actions

    @objc func newTerminal() {
        windowController.welcomeDidSelectNewTerminal()
    }

    @objc func newSplitTerminal() {
        windowController.manager.createSession(label: "Terminal", panel: .secondary)
        // Ensure split is visible — handled in MainWindowController
    }

    @objc func closeTab() {
        if let active = windowController.manager.activeSession(for: .main) {
            windowController.tabBarDidCloseTab(active.id)
        }
    }

    @objc func toggleSplit() {
        windowController.toggleSplit()
    }

    @objc func prevTabAction() {
        windowController.cycleTab(forward: false)
    }

    @objc func nextTabAction() {
        windowController.cycleTab(forward: true)
    }

    @objc func selectTabAction(_ sender: NSMenuItem) {
        windowController.selectTab(index: sender.tag)
    }

    @objc func openSettings() {
        windowController.welcomeDidSelectSettings()
    }
}
