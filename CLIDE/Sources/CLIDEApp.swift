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
        Theme.mode = Theme.Mode(rawValue: settings.theme) ?? .dark
        windowController = MainWindowController(settings: settings)
        setupMenus()

        // Auto-apply layout: CLI --layout flag > default layout > saved session
        if let layoutName = parseLayoutArg(),
           let layout = settings.layouts?.first(where: { $0.name == layoutName }) {
            windowController.applyLayout(layout)
        } else if let defaultLayout = settings.defaultLayout {
            // Default layout always takes priority over saved session
            SavedSession.clear()
            windowController.applyLayout(defaultLayout)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        windowController.manager.saveSession()
    }

    private func parseLayoutArg() -> String? {
        let args = CommandLine.arguments
        if let idx = args.firstIndex(of: "--layout"), idx + 1 < args.count {
            return args[idx + 1]
        }
        return nil
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
        let newSplitItem = NSMenuItem(title: "New Terminal in Column", action: #selector(newSplitTerminal), keyEquivalent: "N")
        newSplitItem.keyEquivalentModifierMask = [.command, .shift]
        newSplitItem.target = self
        fileMenu.addItem(newSplitItem)
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: "Close Tab", action: #selector(closeTab), keyEquivalent: "w").target = self
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: "Save Layout...", action: #selector(saveLayout), keyEquivalent: "").target = self
        let fileMenuItem = NSMenuItem()
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        // Edit menu — send-to actions
        let editMenu = NSMenu(title: "Edit")
        let sendItem = NSMenuItem(title: "Send Selection to Partner", action: #selector(sendToPartner), keyEquivalent: "\r")
        sendItem.keyEquivalentModifierMask = [.command]
        sendItem.target = self
        editMenu.addItem(sendItem)

        let sendRunItem = NSMenuItem(title: "Send Selection & Run", action: #selector(sendAndRunToPartner), keyEquivalent: "\r")
        sendRunItem.keyEquivalentModifierMask = [.command, .shift]
        sendRunItem.target = self
        editMenu.addItem(sendRunItem)

        let editMenuItem = NSMenuItem()
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // View menu
        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(withTitle: "Toggle Column", action: #selector(toggleSplit), keyEquivalent: "\\").target = self

        viewMenu.addItem(.separator())

        let prevTab = NSMenuItem(title: "Previous Tab", action: #selector(prevTabAction), keyEquivalent: "[")
        prevTab.keyEquivalentModifierMask = [.command, .shift]
        prevTab.target = self
        viewMenu.addItem(prevTab)

        let nextTab = NSMenuItem(title: "Next Tab", action: #selector(nextTabAction), keyEquivalent: "]")
        nextTab.keyEquivalentModifierMask = [.command, .shift]
        nextTab.target = self
        viewMenu.addItem(nextTab)

        // Layouts submenu
        let layoutsItem = NSMenuItem(title: "Switch Layout", action: nil, keyEquivalent: "")
        let layoutsSubmenu = LayoutsSubmenu(settings: windowController.settings, controller: windowController)
        layoutsItem.submenu = layoutsSubmenu
        viewMenu.addItem(.separator())
        viewMenu.addItem(layoutsItem)

        let viewMenuItem = NSMenuItem()
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        NSApp.mainMenu = mainMenu
    }

    // MARK: - Menu Actions

    @objc func newTerminal() {
        windowController.createTerminal(inColumn: windowController.focusedColumn() ?? 0)
    }

    @objc func newSplitTerminal() {
        windowController.ensureSplitOpen()
        windowController.createSplitTerminal()
    }

    @objc func closeTab() {
        let col = windowController.focusedColumn() ?? 0
        if let active = windowController.manager.activeSession(forColumn: col) {
            windowController.cellDidClose(active.id)
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

    @objc func sendToPartner() {
        windowController.sendSelectionToPartner(execute: false)
    }

    @objc func sendAndRunToPartner() {
        windowController.sendSelectionToPartner(execute: true)
    }

    @objc func saveLayout() {
        let alert = NSAlert()
        alert.messageText = "Save Current Layout"
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        input.placeholderString = "Layout name"
        alert.accessoryView = input
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            let name = input.stringValue.trimmingCharacters(in: .whitespaces)
            if !name.isEmpty {
                windowController.saveCurrentLayout(name: name)
            }
        }
    }

    @objc func openSettings() {
        windowController.welcomeDidSelectSettings()
    }
}

// MARK: - Dynamic Layouts Submenu

class LayoutsSubmenu: NSMenu, NSMenuDelegate {
    weak var controller: MainWindowController?
    var settings: AppSettings

    init(settings: AppSettings, controller: MainWindowController) {
        self.settings = settings
        self.controller = controller
        super.init(title: "Switch Layout")
        self.delegate = self
    }

    required init(coder: NSCoder) { fatalError() }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        // Reload settings in case layouts were added/changed
        let current = AppSettings.load()
        self.settings = current

        guard let layouts = current.layouts, !layouts.isEmpty else {
            let empty = NSMenuItem(title: "No saved layouts", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
            return
        }

        for layout in layouts {
            let defaultMark = layout.isDefault ? " \u{2713}" : ""
            let item = NSMenuItem(title: "\(layout.name)\(defaultMark)", action: #selector(applyLayout(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = layout.id
            menu.addItem(item)
        }
    }

    @objc func applyLayout(_ sender: NSMenuItem) {
        guard let layoutId = sender.representedObject as? UUID,
              let layout = settings.layouts?.first(where: { $0.id == layoutId }) else { return }
        controller?.applyLayout(layout)
    }
}
