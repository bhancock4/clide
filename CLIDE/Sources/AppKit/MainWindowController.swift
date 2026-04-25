import AppKit
import SwiftTerm

class MainWindowController: NSObject, WelcomeViewControllerDelegate, TerminalTabBarDelegate, LocalProcessTerminalViewDelegate {

    let window: NSWindow
    let manager: SessionManager
    var settings: AppSettings

    // Views
    private let rootView = NSView()
    private var welcomeVC: WelcomeViewController?
    private let mainTabBar = TerminalTabBar()
    private let splitTabBar = TerminalTabBar()
    private let splitView = NSSplitView()
    private let mainContainer = NSView()
    private let splitContainer = NSView()
    private let toolbar = NSView()
    private var workspaceView = NSView()

    private var splitVisible = false

    init(settings: AppSettings) {
        self.settings = settings
        self.manager = SessionManager(settings: settings)

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 800),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "CLIDE"
        window.minSize = NSSize(width: 800, height: 500)
        window.center()

        super.init()

        setupUI()
        showWelcome()

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - UI Setup

    private func setupUI() {
        rootView.wantsLayer = true
        rootView.layer?.backgroundColor = Theme.bgPrimary.cgColor
        window.contentView = rootView

        // Build workspace (hidden initially)
        buildWorkspace()
    }

    private func buildWorkspace() {
        workspaceView.translatesAutoresizingMaskIntoConstraints = false
        workspaceView.wantsLayer = true

        let mainPanel = buildPanel(tabBar: mainTabBar, container: mainContainer, toolbar: buildToolbar())
        let splitPanel = buildPanel(tabBar: splitTabBar, container: splitContainer, toolbar: buildSplitToolbar())

        mainTabBar.delegate = self
        splitTabBar.delegate = self

        // NSSplitView
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.translatesAutoresizingMaskIntoConstraints = false
        splitView.addArrangedSubview(mainPanel)
        splitView.addArrangedSubview(splitPanel)

        workspaceView.addSubview(splitView)
        NSLayoutConstraint.activate([
            splitView.topAnchor.constraint(equalTo: workspaceView.topAnchor),
            splitView.bottomAnchor.constraint(equalTo: workspaceView.bottomAnchor),
            splitView.leadingAnchor.constraint(equalTo: workspaceView.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: workspaceView.trailingAnchor),
        ])

        // Initially hide split panel
        splitView.arrangedSubviews[1].isHidden = true
    }

    /// Builds a panel with a fixed-height header bar on top and a clipped terminal
    /// container below. The header bar contains the tab bar and toolbar buttons.
    private func buildPanel(tabBar: TerminalTabBar, container: NSView, toolbar: NSStackView) -> NSView {
        let panel = NSView()
        panel.wantsLayer = true
        panel.translatesAutoresizingMaskIntoConstraints = false

        // Fixed-height header bar
        let header = NSView()
        header.wantsLayer = true
        header.layer?.backgroundColor = Theme.bgSecondary.cgColor
        header.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(header)

        tabBar.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(tabBar)

        toolbar.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(toolbar)

        // Separator line below header
        let separator = NSView()
        separator.wantsLayer = true
        separator.layer?.backgroundColor = Theme.border.cgColor
        separator.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(separator)

        // Terminal container — clips its content
        container.translatesAutoresizingMaskIntoConstraints = false
        container.wantsLayer = true
        container.layer?.backgroundColor = Theme.bgPrimary.cgColor
        container.layer?.masksToBounds = true
        panel.addSubview(container)

        let headerHeight: CGFloat = 34

        NSLayoutConstraint.activate([
            // Header: fixed height, full width, at top
            header.topAnchor.constraint(equalTo: panel.topAnchor),
            header.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: headerHeight),

            // Tab bar fills header, leaving room for toolbar
            tabBar.topAnchor.constraint(equalTo: header.topAnchor),
            tabBar.bottomAnchor.constraint(equalTo: header.bottomAnchor),
            tabBar.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: toolbar.leadingAnchor, constant: -4),

            // Toolbar pinned to right of header
            toolbar.topAnchor.constraint(equalTo: header.topAnchor),
            toolbar.bottomAnchor.constraint(equalTo: header.bottomAnchor),
            toolbar.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -8),

            // Separator: 1px line below header
            separator.topAnchor.constraint(equalTo: header.bottomAnchor),
            separator.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1),

            // Container: fills remaining space below separator
            container.topAnchor.constraint(equalTo: separator.bottomAnchor),
            container.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: panel.bottomAnchor),
        ])

        return panel
    }

    private func buildToolbar() -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 4

        let splitBtn = CallbackButton(title: "│", action: { [weak self] in self?.toggleSplit() })
        splitBtn.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        splitBtn.isBordered = false
        splitBtn.contentTintColor = Theme.textSecondary
        splitBtn.toolTip = "Split View (Cmd+\\)"

        let newBtn = CallbackButton(title: "+", action: { [weak self] in self?.createMainTerminal() })
        newBtn.font = NSFont.monospacedSystemFont(ofSize: 16, weight: .regular)
        newBtn.isBordered = false
        newBtn.contentTintColor = Theme.textSecondary
        newBtn.toolTip = "New Terminal (Cmd+N)"

        let settingsBtn = CallbackButton(title: "⚙", action: { [weak self] in self?.openSettings() })
        settingsBtn.font = NSFont.systemFont(ofSize: 14)
        settingsBtn.isBordered = false
        settingsBtn.contentTintColor = Theme.textSecondary
        settingsBtn.toolTip = "Settings (Cmd+,)"

        let homeBtn = CallbackButton(title: "⌂", action: { [weak self] in self?.goHome() })
        homeBtn.font = NSFont.monospacedSystemFont(ofSize: 16, weight: .regular)
        homeBtn.isBordered = false
        homeBtn.contentTintColor = Theme.textSecondary
        homeBtn.toolTip = "Home"

        stack.addArrangedSubview(splitBtn)
        stack.addArrangedSubview(newBtn)
        stack.addArrangedSubview(settingsBtn)
        stack.addArrangedSubview(homeBtn)
        return stack
    }

    private func buildSplitToolbar() -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 4

        let newBtn = CallbackButton(title: "+", action: { [weak self] in self?.createSplitTerminal() })
        newBtn.font = NSFont.monospacedSystemFont(ofSize: 16, weight: .regular)
        newBtn.isBordered = false
        newBtn.contentTintColor = Theme.textSecondary

        let closeBtn = CallbackButton(title: "✕", action: { [weak self] in self?.closeSplit() })
        closeBtn.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        closeBtn.isBordered = false
        closeBtn.contentTintColor = Theme.textSecondary

        stack.addArrangedSubview(newBtn)
        stack.addArrangedSubview(closeBtn)
        return stack
    }

    // MARK: - View Switching

    private func showWelcome() {
        workspaceView.removeFromSuperview()

        let hasSaved = !CommandLine.arguments.contains("--new") && SavedSession.load().hasSavedTerminals
        welcomeVC = WelcomeViewController(settings: settings, hasSavedSession: hasSaved)
        welcomeVC?.delegate = self
        let wcView = welcomeVC!.view
        wcView.translatesAutoresizingMaskIntoConstraints = false
        rootView.addSubview(wcView)

        NSLayoutConstraint.activate([
            wcView.topAnchor.constraint(equalTo: rootView.topAnchor),
            wcView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
            wcView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            wcView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
        ])

        window.makeFirstResponder(wcView)
    }

    private func showWorkspace() {
        welcomeVC?.view.removeFromSuperview()
        welcomeVC = nil

        workspaceView.translatesAutoresizingMaskIntoConstraints = false
        rootView.addSubview(workspaceView)

        NSLayoutConstraint.activate([
            workspaceView.topAnchor.constraint(equalTo: rootView.topAnchor),
            workspaceView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
            workspaceView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            workspaceView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
        ])

        refreshTabs()
        showActiveTerminal(panel: .main)
    }

    // MARK: - Terminal Management

    private func createMainTerminal() {
        guard let cwd = NewSessionDialog.prompt(defaultCwd: settings.defaultCwd, in: window) else { return }
        manager.createSession(label: "Terminal", panel: .main, cwd: cwd)
        if welcomeVC != nil { showWorkspace() }
        refreshTabs()
        showActiveTerminal(panel: .main)
    }

    private func createSplitTerminal() {
        guard let cwd = NewSessionDialog.prompt(defaultCwd: settings.defaultCwd, in: window) else { return }
        manager.createSession(label: "Terminal", panel: .secondary, cwd: cwd)
        refreshTabs()
        showActiveTerminal(panel: .secondary)
    }

    private func showActiveTerminal(panel: TerminalSession.Panel) {
        guard let session = manager.activeSession(for: panel) else { return }
        let container = panel == .main ? mainContainer : splitContainer

        // Remove old terminal view
        container.subviews.forEach { $0.removeFromSuperview() }

        let tv = session.terminalView
        tv.processDelegate = self
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.removeFromSuperview()
        container.addSubview(tv)

        // Set up right-click context menu for send-to-terminal
        tv.menu = buildSendToMenu(sourceSession: session)

        NSLayoutConstraint.activate([
            tv.topAnchor.constraint(equalTo: container.topAnchor),
            tv.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            tv.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            tv.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])

        window.makeFirstResponder(tv)
    }

    private func refreshTabs() {
        mainTabBar.update(tabs: manager.mainSessions.enumerated().map { idx, s in
            tabInfo(for: s, active: s.id == manager.activeMainId, index: idx)
        })
        splitTabBar.update(tabs: manager.secondarySessions.enumerated().map { idx, s in
            tabInfo(for: s, active: s.id == manager.activeSecondaryId, index: idx)
        })
    }

    private func tabInfo(for session: TerminalSession, active: Bool, index: Int) -> TerminalTabBar.TabInfo {
        return TerminalTabBar.TabInfo(
            id: session.id,
            label: session.label,
            color: NSColor.fromHex(colorForCommand(session.command)) ?? .gray,
            isActive: active,
            index: index
        )
    }

    private func colorForCommand(_ cmd: String) -> String {
        settings.tools.first { $0.command == cmd }?.color ?? "#8b949e"
    }

    // MARK: - Send to Terminal (bidirectional)

    private func buildSendToMenu(sourceSession: TerminalSession) -> NSMenu {
        let menu = SendToMenu(manager: manager, sourceSession: sourceSession, controller: self)
        return menu
    }

    func sendSelection(from source: TerminalSession, to target: TerminalSession, execute: Bool) {
        guard let text = source.terminalView.getSelection(), !text.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "No text selected"
            alert.informativeText = "Select text in the terminal first, then right-click to send it."
            alert.runModal()
            return
        }

        let payload = execute ? text + "\n" : text
        let bytes = Array(payload.utf8)
        target.terminalView.send(source: target.terminalView, data: bytes[...])
    }

    // MARK: - Split View

    func toggleSplit() {
        if splitVisible {
            closeSplit()
        } else {
            openSplit()
        }
    }

    private func openSplit() {
        splitVisible = true
        splitView.arrangedSubviews[1].isHidden = false
        if manager.secondarySessions.isEmpty {
            createSplitTerminal()
        } else {
            refreshTabs()
            showActiveTerminal(panel: .secondary)
        }
    }

    private func closeSplit() {
        splitVisible = false
        splitView.arrangedSubviews[1].isHidden = true
    }

    private func goHome() {
        manager.saveSession()
        showWelcome()
    }

    private func openSettings() {
        SettingsPanel.show(in: window, settings: &settings) { [weak self] newSettings in
            self?.settings = newSettings
            self?.manager.settings = newSettings
        }
    }

    // MARK: - Tab Cycling (called from app delegate)

    func cycleTab(forward: Bool) {
        manager.cycleTab(panel: .main, forward: forward)
        refreshTabs()
        showActiveTerminal(panel: .main)
    }

    func selectTab(index: Int) {
        manager.selectTab(index: index, panel: .main)
        refreshTabs()
        showActiveTerminal(panel: .main)
    }

    // MARK: - WelcomeViewControllerDelegate

    func welcomeDidSelectTool(_ tool: ToolConfig) {
        guard let cwd = NewSessionDialog.prompt(defaultCwd: settings.defaultCwd, in: window) else { return }
        manager.createSession(label: tool.name, command: tool.command, args: tool.args, panel: .main, cwd: cwd)
        showWorkspace()
        showActiveTerminal(panel: .main)
    }

    func welcomeDidSelectNewTerminal() {
        createMainTerminal()
    }

    func welcomeDidSelectRestoreSession() {
        manager.restoreSession()
        splitVisible = !manager.secondarySessions.isEmpty
        if splitVisible {
            splitView.arrangedSubviews[1].isHidden = false
        }
        showWorkspace()
        if splitVisible { showActiveTerminal(panel: .secondary) }
    }

    func welcomeDidSelectSettings() {
        openSettings()
    }

    // MARK: - TerminalTabBarDelegate

    func tabBarDidSelectTab(_ id: UUID) {
        guard let session = manager.sessions.first(where: { $0.id == id }) else { return }
        manager.setActive(id, panel: session.panel)
        refreshTabs()
        showActiveTerminal(panel: session.panel)
    }

    func tabBarDidCloseTab(_ id: UUID) {
        guard let session = manager.sessions.first(where: { $0.id == id }) else { return }
        let panel = session.panel
        manager.closeSession(id)

        if panel == .secondary && manager.secondarySessions.isEmpty {
            closeSplit()
        }
        if !manager.hasAnySessions {
            goHome()
            return
        }
        refreshTabs()
        showActiveTerminal(panel: panel)
    }

    func tabBarDidDoubleClickTab(_ id: UUID) {
        guard let session = manager.sessions.first(where: { $0.id == id }) else { return }
        let alert = NSAlert()
        alert.messageText = "Rename Terminal"
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        input.stringValue = session.label
        alert.accessoryView = input
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            let newName = input.stringValue.trimmingCharacters(in: .whitespaces)
            if !newName.isEmpty {
                session.label = newName
                refreshTabs()
            }
        }
    }

    func tabBarDidRequestNewTab() {
        // Determine which tab bar triggered this
        createMainTerminal()
    }

    // MARK: - LocalProcessTerminalViewDelegate

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        if !title.isEmpty {
            window.title = "CLIDE — \(title)"
        }
    }

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        // Find and close the session whose terminal matches
        if let session = manager.sessions.first(where: { $0.terminalView === source }) {
            DispatchQueue.main.async { [weak self] in
                self?.tabBarDidCloseTab(session.id)
            }
        }
    }
}
