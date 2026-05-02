import AppKit
import SwiftTerm

class MainWindowController: NSObject, WelcomeViewControllerDelegate, TerminalCellDelegate, LocalProcessTerminalViewDelegate {

    let window: NSWindow
    let manager: SessionManager
    var settings: AppSettings

    // Views
    private let rootView = NSView()
    private var welcomeVC: WelcomeViewController?
    private let horizontalSplit = NSSplitView()
    private var workspaceView = NSView()

    // Dynamic columns
    private var columns: [ColumnView] = []

    struct ColumnView {
        var index: Int
        let container: NSView
        let stack: NSSplitView
    }

    // Cell tracking
    private var cellViews: [UUID: NSView] = [:]
    private var cellHeaders: [UUID: TerminalCellHeader] = [:]

    // Broadcast typing — additional terminals that receive keystrokes
    var broadcastTargets: Set<UUID> = []
    private var keyMonitor: Any?
    private var focusMonitor: Any?

    private var selectionMonitor: Any?
    private var selectionBar: SelectionActionBar?
    private var sessionCwd: String?

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
        window.setFrameAutosaveName("CLIDEMainWindow")
        if !window.setFrameUsingName("CLIDEMainWindow") {
            window.center()
        }

        super.init()

        setupUI()
        showWelcome()
        startSelectionMonitoring()
        startBroadcastMonitoring()
        trackFocusChanges()

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - UI Setup

    private func setupUI() {
        rootView.wantsLayer = true
        rootView.layer?.backgroundColor = Theme.bgPrimary.cgColor
        window.contentView = rootView
        buildWorkspace()
    }

    private func buildWorkspace() {
        workspaceView.translatesAutoresizingMaskIntoConstraints = false
        workspaceView.wantsLayer = true

        horizontalSplit.isVertical = true
        horizontalSplit.dividerStyle = .thin
        horizontalSplit.translatesAutoresizingMaskIntoConstraints = false

        workspaceView.addSubview(horizontalSplit)
        NSLayoutConstraint.activate([
            horizontalSplit.topAnchor.constraint(equalTo: workspaceView.topAnchor),
            horizontalSplit.bottomAnchor.constraint(equalTo: workspaceView.bottomAnchor),
            horizontalSplit.leadingAnchor.constraint(equalTo: workspaceView.leadingAnchor),
            horizontalSplit.trailingAnchor.constraint(equalTo: workspaceView.trailingAnchor),
        ])
    }

    // MARK: - Column Management

    @discardableResult
    private func addColumnView(at index: Int) -> ColumnView {
        let stack = NSSplitView()
        stack.isVertical = false   // horizontal dividers → vertical stacking
        stack.dividerStyle = .thin
        stack.translatesAutoresizingMaskIntoConstraints = false

        let toolbar = buildColumnToolbar(column: index)
        let panel = buildPanel(stack: stack, toolbar: toolbar, showBranding: index == 0)

        horizontalSplit.addArrangedSubview(panel)
        let col = ColumnView(index: index, container: panel, stack: stack)
        columns.append(col)

        // Give the new column 1/3 of the horizontal space
        DispatchQueue.main.async { [weak self] in
            self?.distributeColumnSpace()
        }

        return col
    }

    private func removeColumnView(at colIndex: Int) {
        guard let idx = columns.firstIndex(where: { $0.index == colIndex }) else { return }

        // Remove all cells in this column
        for session in manager.sessions(forColumn: colIndex) {
            removeTerminalCell(session.id)
        }

        let col = columns[idx]
        col.container.removeFromSuperview()
        columns.remove(at: idx)

        manager.removeColumn(colIndex)

        // Re-index remaining columns
        for i in columns.indices {
            columns[i].index = i
        }

        if !manager.hasAnySessions {
            goHome()
        }
    }

    /// Rebuild all column views and terminal cells from current session state.
    func rebuildAllColumns() {
        // Clear existing
        for col in columns {
            col.container.removeFromSuperview()
        }
        columns.removeAll()
        cellViews.removeAll()
        cellHeaders.removeAll()

        // Create columns
        for colIdx in 0..<manager.columnCount {
            addColumnView(at: colIdx)
        }

        // Add terminal cells
        for session in manager.sessions {
            addTerminalCell(session)
        }
    }

    private func columnStack(for colIndex: Int) -> NSSplitView? {
        columns.first(where: { $0.index == colIndex })?.stack
    }

    /// Distribute columns so new ones get ~1/3 of the total width.
    private func distributeColumnSpace() {
        let count = horizontalSplit.arrangedSubviews.filter { !$0.isHidden }.count
        guard count > 1 else { return }
        let totalWidth = horizontalSplit.bounds.width
        let dividerWidth = horizontalSplit.dividerThickness
        let usable = totalWidth - CGFloat(count - 1) * dividerWidth

        // New column gets 1/3 or equal share, whichever is smaller
        let newShare = min(usable / 3, usable / CGFloat(count))
        let existingShare = (usable - newShare) / CGFloat(count - 1)

        var pos: CGFloat = 0
        for i in 0..<(count - 1) {
            pos += (i == count - 2) ? existingShare : existingShare
            horizontalSplit.setPosition(pos + CGFloat(i) * dividerWidth, ofDividerAt: i)
        }
    }

    /// Distribute terminals within a column so new ones get ~1/3 of the height.
    private func distributeTerminalSpace(in stack: NSSplitView) {
        let count = stack.arrangedSubviews.count
        guard count > 1 else { return }
        let totalHeight = stack.bounds.height
        let dividerHeight = stack.dividerThickness
        let usable = totalHeight - CGFloat(count - 1) * dividerHeight

        let newShare = min(usable / 3, usable / CGFloat(count))
        let existingShare = (usable - newShare) / CGFloat(count - 1)

        var pos: CGFloat = 0
        for i in 0..<(count - 1) {
            pos += existingShare
            stack.setPosition(pos + CGFloat(i) * dividerHeight, ofDividerAt: i)
        }
    }

    // MARK: - Panel Building

    private func buildPanel(stack: NSSplitView, toolbar: NSStackView, showBranding: Bool = false) -> NSView {
        let panel = NSView()
        panel.wantsLayer = true
        panel.translatesAutoresizingMaskIntoConstraints = false

        let header = NSView()
        header.wantsLayer = true
        header.layer?.backgroundColor = Theme.bgSecondary.cgColor
        header.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(header)

        // CLIDE branding in the upper-left
        if showBranding {
            let brandLabel = NSTextField(labelWithString: "CLIDE")
            brandLabel.font = NSFont.monospacedSystemFont(ofSize: 24, weight: .bold)
            brandLabel.textColor = Theme.accentGold.withAlphaComponent(0.6)
            brandLabel.translatesAutoresizingMaskIntoConstraints = false
            header.addSubview(brandLabel)
            NSLayoutConstraint.activate([
                brandLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 10),
                brandLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            ])
        }

        toolbar.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(toolbar)

        let separator = NSView()
        separator.wantsLayer = true
        separator.layer?.backgroundColor = Theme.border.cgColor
        separator.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(separator)

        panel.addSubview(stack)

        let headerHeight: CGFloat = 36

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: panel.topAnchor),
            header.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: headerHeight),

            toolbar.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -8),
            toolbar.centerYAnchor.constraint(equalTo: header.centerYAnchor),

            separator.topAnchor.constraint(equalTo: header.bottomAnchor),
            separator.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1),

            stack.topAnchor.constraint(equalTo: separator.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: panel.bottomAnchor),
        ])

        return panel
    }

    // MARK: - Toolbar

    private func makeToolbarButton(symbol: String, tooltip: String, action: @escaping () -> Void) -> CallbackButton {
        let btn = CallbackButton(title: "", action: action)
        btn.image = NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip)
        btn.imagePosition = .imageOnly
        btn.symbolConfiguration = .init(pointSize: 16, weight: .medium)
        btn.isBordered = false
        btn.contentTintColor = Theme.textSecondary
        btn.toolTip = tooltip
        btn.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            btn.widthAnchor.constraint(equalToConstant: 30),
            btn.heightAnchor.constraint(equalToConstant: 30),
        ])
        return btn
    }

    private func buildColumnToolbar(column: Int) -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 2

        // Every column gets: add column + new terminal
        stack.addArrangedSubview(makeToolbarButton(symbol: "sidebar.right", tooltip: "Add Column") { [weak self] in
            self?.addColumnToRight(of: column)
        })
        stack.addArrangedSubview(makeToolbarButton(symbol: "plus", tooltip: "New Terminal") { [weak self] in
            self?.createTerminal(inColumn: column)
        })

        if column == 0 {
            stack.addArrangedSubview(makeToolbarButton(symbol: "gearshape", tooltip: "Settings (Cmd+,)") { [weak self] in self?.openSettings() })
            stack.addArrangedSubview(makeToolbarButton(symbol: "house", tooltip: "Home") { [weak self] in self?.goHome() })
        } else {
            stack.addArrangedSubview(makeToolbarButton(symbol: "xmark", tooltip: "Close Column") { [weak self] in
                self?.removeColumnView(at: column)
            })
        }

        return stack
    }

    // MARK: - View Switching

    private func showWelcome() {
        workspaceView.removeFromSuperview()
        hideSelectionBar()

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
    }

    // MARK: - Terminal Cell Management

    private func addTerminalCell(_ session: TerminalSession) {
        guard let stack = columnStack(for: session.column) else { return }

        let cell = NSView()
        cell.wantsLayer = true
        cell.translatesAutoresizingMaskIntoConstraints = false

        let color = NSColor.fromHex(colorForCommand(session.command)) ?? .gray
        let header = TerminalCellHeader(sessionId: session.id, label: session.label, color: color, delegate: self)

        // Update pairing stripes
        let groups = manager.pairings(for: session.id)
        header.updatePairings(groups)

        let tv = session.terminalView
        tv.processDelegate = self
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.menu = buildSendToMenu(sourceSession: session)

        cell.addSubview(header)
        cell.addSubview(tv)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: cell.topAnchor),
            header.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: cell.trailingAnchor),

            tv.topAnchor.constraint(equalTo: header.bottomAnchor),
            tv.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
            tv.trailingAnchor.constraint(equalTo: cell.trailingAnchor),
            tv.bottomAnchor.constraint(equalTo: cell.bottomAnchor),
        ])

        stack.addArrangedSubview(cell)
        cellViews[session.id] = cell
        cellHeaders[session.id] = header

        // Give the new terminal 1/3 of the column height
        DispatchQueue.main.async { [weak self] in
            self?.distributeTerminalSpace(in: stack)
        }

        updateFocusIndicators()
        window.makeFirstResponder(tv)
    }

    private func removeTerminalCell(_ id: UUID) {
        cellViews[id]?.removeFromSuperview()
        cellViews.removeValue(forKey: id)
        cellHeaders.removeValue(forKey: id)
    }

    func updateFocusIndicators() {
        let focusedId = focusedSession()?.id
        for (id, header) in cellHeaders {
            header.isActive = (id == focusedId)
            header.isBroadcasting = broadcastTargets.contains(id)
        }
    }

    func updateAllPairingIndicators() {
        for (id, header) in cellHeaders {
            header.updatePairings(manager.pairings(for: id))
        }
    }

    // MARK: - Terminal Creation

    private func resolveWorkingDirectory() -> String? {
        if let cwd = sessionCwd, settings.promptForDirectory != true {
            return cwd
        }
        guard let cwd = NewSessionDialog.prompt(defaultCwd: sessionCwd ?? settings.defaultCwd, in: window) else {
            return nil
        }
        if sessionCwd == nil { sessionCwd = cwd }
        return cwd
    }

    func createTerminal(inColumn col: Int) {
        guard let cwd = resolveWorkingDirectory() else { return }
        let label = manager.nextLabel(baseName: "Terminal")
        let session = manager.createSession(label: label, column: col, cwd: cwd)
        if welcomeVC != nil {
            showWorkspace()
            // Ensure column 0 exists
            if columns.isEmpty { addColumnView(at: 0) }
        }
        // Ensure column view exists
        if columnStack(for: col) == nil {
            addColumnView(at: col)
        }
        addTerminalCell(session)
    }

    func createSplitTerminal() {
        // Add to the next column (creating it if needed)
        let col = manager.columnCount > 1 ? manager.columnCount - 1 : 1
        if col >= manager.columnCount { _ = manager.addColumn() }
        createTerminal(inColumn: col)
    }

    private func addColumnToRight(of col: Int) {
        let newCol = manager.addColumn()
        addColumnView(at: newCol)
        createTerminal(inColumn: newCol)
    }

    private func colorForCommand(_ cmd: String) -> String {
        settings.tools.first { $0.command == cmd }?.color ?? "#8b949e"
    }

    // MARK: - Send to Terminal

    private func buildSendToMenu(sourceSession: TerminalSession) -> NSMenu {
        SendToMenu(manager: manager, sourceSession: sourceSession, controller: self)
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

    /// Send to all paired terminals, or fall back to adjacent column active terminal.
    func sendSelectionToPartner(execute: Bool) {
        guard let source = focusedSession() else { return }

        let paired = manager.pairedSessions(for: source.id)
        if !paired.isEmpty {
            for target in paired {
                sendSelection(from: source, to: target, execute: execute)
            }
            return
        }

        let otherCol = source.column == 0 ? 1 : source.column - 1
        guard let target = manager.activeSession(forColumn: otherCol) else { return }
        sendSelection(from: source, to: target, execute: execute)
    }

    private func focusedSession() -> TerminalSession? {
        guard let tv = window.firstResponder as? LocalProcessTerminalView else { return nil }
        return manager.sessions.first(where: { $0.terminalView === tv })
    }

    // MARK: - Selection Monitoring

    private func startSelectionMonitoring() {
        selectionMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] event in
            DispatchQueue.main.async { self?.checkForSelection() }
            return event
        }
    }

    private func checkForSelection() {
        guard columns.count > 1 else {
            hideSelectionBar()
            return
        }

        // Don't dismiss the bar if the user is interacting with it or its popover
        if let bar = selectionBar {
            if bar.hasActivePopover { return }
            if let firstResponder = window.firstResponder as? NSView,
               firstResponder.isDescendant(of: bar) || firstResponder === bar {
                return
            }
        }

        guard let tv = window.firstResponder as? LocalProcessTerminalView,
              let source = manager.sessions.first(where: { $0.terminalView === tv }),
              let selection = tv.getSelection(), !selection.isEmpty else {
            hideSelectionBar()
            return
        }

        // If bar already exists for this source, keep it (preserves toggle state)
        if let bar = selectionBar, bar.sourceId == source.id {
            return
        }

        guard let cell = cellViews[source.id] else {
            hideSelectionBar()
            return
        }

        // Build target list: paired terminals are on by default, others available
        let paired = Set(manager.pairedSessions(for: source.id).map(\.id))
        let allTargets = manager.sessions.filter { $0.id != source.id }
        guard !allTargets.isEmpty else {
            hideSelectionBar()
            return
        }

        // Default active set: paired terminals, or adjacent column active if no pairings
        let defaultActive: Set<UUID>
        if !paired.isEmpty {
            defaultActive = paired
        } else {
            let otherCol = source.column == 0 ? 1 : source.column - 1
            if let adj = manager.activeSession(forColumn: otherCol) {
                defaultActive = [adj.id]
            } else {
                defaultActive = [allTargets[0].id]
            }
        }

        showSelectionBar(source: source, allTargets: allTargets, defaultActive: defaultActive, in: cell)
    }

    private func showSelectionBar(source: TerminalSession, allTargets: [TerminalSession], defaultActive: Set<UUID>, in container: NSView) {
        hideSelectionBar()

        let bar = SelectionActionBar(
            sourceId: source.id,
            allTargets: allTargets,
            defaultActive: defaultActive,
            onSend: { [weak self] targets in
                for t in targets { self?.sendSelection(from: source, to: t, execute: false) }
            },
            onSendAndRun: { [weak self] targets in
                for t in targets { self?.sendSelection(from: source, to: t, execute: true) }
            }
        )
        bar.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(bar)

        NSLayoutConstraint.activate([
            bar.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
            bar.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            bar.heightAnchor.constraint(equalToConstant: 34),
        ])

        selectionBar = bar
    }

    func hideSelectionBar() {
        selectionBar?.removeFromSuperview()
        selectionBar = nil
    }

    // MARK: - Split / Column Toggle

    /// Toggle column 1 (backward-compat for Cmd+\)
    func toggleSplit() {
        if columns.count > 1 {
            // Remove last column
            removeColumnView(at: columns.last!.index)
        } else {
            addColumnToRight(of: 0)
        }
    }

    func ensureSplitOpen() {
        if columns.count <= 1 {
            let newCol = manager.addColumn()
            addColumnView(at: newCol)
        }
    }

    private func goHome() {
        manager.saveSession()
        showWelcome()
    }

    private func openSettings() {
        SettingsPanel.show(in: window, settings: &settings, onSave: { [weak self] newSettings in
            self?.settings = newSettings
            self?.manager.settings = newSettings
        }, onSaveCurrentLayout: manager.hasAnySessions ? { [weak self] in
            guard let self else { return }
            let alert = NSAlert()
            alert.messageText = "Save Current Layout"
            let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
            input.placeholderString = "Layout name"
            alert.accessoryView = input
            alert.addButton(withTitle: "Save")
            alert.addButton(withTitle: "Cancel")
            if alert.runModal() == .alertFirstButtonReturn {
                let name = input.stringValue.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { self.saveCurrentLayout(name: name) }
            }
        } : nil)
    }

    // MARK: - Focus Cycling

    func cycleTab(forward: Bool) {
        let col = focusedColumn() ?? 0
        manager.cycleTab(column: col, forward: forward)
        focusActiveTerminal(column: col)
    }

    func selectTab(index: Int) {
        let col = focusedColumn() ?? 0
        manager.selectTab(index: index, column: col)
        focusActiveTerminal(column: col)
    }

    private func focusActiveTerminal(column: Int) {
        guard let session = manager.activeSession(forColumn: column) else { return }
        window.makeFirstResponder(session.terminalView)
        updateFocusIndicators()
    }

    func focusedColumn() -> Int? {
        guard let session = focusedSession() else { return nil }
        return session.column
    }

    // MARK: - Layout Application

    func applyLayout(_ layout: TerminalLayout) {
        guard let cwd = resolveWorkingDirectory() else { return }

        // Prompt if closing active terminals
        let activeSessions = manager.sessions.filter { $0.isAlive }
        let layoutTerminalCount = layout.columns.reduce(0) { $0 + $1.terminals.count }

        if !activeSessions.isEmpty && activeSessions.count > layoutTerminalCount {
            let alert = NSAlert()
            alert.messageText = "Switch Layout?"
            alert.informativeText = "This will close \(activeSessions.count - layoutTerminalCount) active terminal(s). Continue?"
            alert.addButton(withTitle: "Switch")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }

        // Clear everything
        closeAllSessions()
        manager.applyLayout(layout, cwd: cwd)

        // Restore window frame if saved
        if let f = layout.windowFrame {
            window.setFrame(NSRect(x: f.x, y: f.y, width: f.width, height: f.height), display: true)
        }

        showWorkspace()
        rebuildAllColumns()
    }

    func saveCurrentLayout(name: String) {
        var layout = manager.captureLayout(name: name, windowFrame: window.frame)
        if settings.layouts?.isEmpty != false {
            layout.isDefault = true
        }
        if settings.layouts == nil { settings.layouts = [] }
        settings.layouts?.append(layout)
        saveSettingsWithAlert()
    }

    /// Save settings with error reporting to the user.
    private func saveSettingsWithAlert() {
        do {
            try settings.save()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Failed to save settings"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    private func closeAllSessions() {
        for session in manager.sessions {
            removeTerminalCell(session.id)
        }
        manager.sessions.removeAll()
        manager.activeIds.removeAll()
        manager.pairingGroups.removeAll()
        for col in columns {
            col.container.removeFromSuperview()
        }
        columns.removeAll()
        manager.columnCount = 1
    }

    // MARK: - WelcomeViewControllerDelegate

    func welcomeDidSelectTool(_ tool: ToolConfig) {
        guard let cwd = resolveWorkingDirectory() else { return }
        let session = manager.createSession(label: tool.name, command: tool.command, args: tool.args, column: 0, cwd: cwd)
        showWorkspace()
        if columns.isEmpty { addColumnView(at: 0) }
        addTerminalCell(session)
    }

    func welcomeDidSelectNewTerminal() {
        createTerminal(inColumn: 0)
    }

    func welcomeDidSelectRestoreSession() {
        manager.restoreSession()
        showWorkspace()

        for colIdx in 0..<manager.columnCount {
            addColumnView(at: colIdx)
        }
        for session in manager.sessions {
            addTerminalCell(session)
        }
    }

    func welcomeDidSelectSettings() {
        openSettings()
    }

    func welcomeDidSelectLayout(_ layout: TerminalLayout) {
        applyLayout(layout)
    }

    // MARK: - TerminalCellDelegate

    func cellDidSelect(_ id: UUID) {
        guard let session = manager.session(byId: id) else { return }
        // Clicking a header just focuses that terminal
        manager.setActive(id, column: session.column)
        window.makeFirstResponder(session.terminalView)
        updateFocusIndicators()
    }

    func cellDidToggleBroadcast(_ id: UUID) {
        if broadcastTargets.contains(id) {
            broadcastTargets.remove(id)
        } else {
            broadcastTargets.insert(id)
        }
        updateFocusIndicators()
    }

    func cellDidClose(_ id: UUID) {
        guard let session = manager.session(byId: id) else { return }
        let col = session.column

        removeTerminalCell(id)
        manager.closeSession(id)
        broadcastTargets.remove(id)
        updateAllPairingIndicators()

        // If column is now empty and it's not column 0, remove it
        if manager.sessions(forColumn: col).isEmpty && col > 0 {
            removeColumnView(at: col)
            return
        }

        if !manager.hasAnySessions {
            goHome()
            return
        }

        focusActiveTerminal(column: col)
    }

    func cellDidDoubleClick(_ id: UUID) {
        guard let session = manager.session(byId: id) else { return }
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
                session.hasCustomLabel = true
                cellHeaders[id]?.updateLabel(newName)
            }
        }
    }

    func cellDidRequestPairing(source: UUID, target: UUID) {
        _ = manager.createPairing(between: [source, target])
        updateAllPairingIndicators()
    }

    /// Retained reference so the menu stays alive during display.
    private var activePairMenu: PairContextMenu?

    func cellDidRightClick(_ id: UUID, event: NSEvent, view: NSView) {
        let menu = PairContextMenu(sessionId: id, manager: manager, controller: self)
        activePairMenu = menu
        NSMenu.popUpContextMenu(menu, with: event, for: view)
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
        if let session = manager.sessions.first(where: { $0.terminalView === source }) {
            DispatchQueue.main.async { [weak self] in
                self?.cellDidClose(session.id)
            }
        }
    }

    // MARK: - Broadcast Typing

    private func startBroadcastMonitoring() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            self?.broadcastKey(event)
            return event  // always pass through to focused terminal
        }
    }

    private func broadcastKey(_ event: NSEvent) {
        guard !broadcastTargets.isEmpty else { return }
        guard let focused = focusedSession() else { return }
        guard window.firstResponder is LocalProcessTerminalView else { return }

        // When the user types in a terminal that's part of the broadcast group,
        // it becomes the sender — broadcast to all OTHER members
        let allMembers = broadcastTargets.union([focused.id])

        for targetId in allMembers {
            guard targetId != focused.id,
                  let target = manager.session(byId: targetId) else { continue }

            if let chars = event.characters, !chars.isEmpty {
                let bytes = Array(chars.utf8)
                target.terminalView.send(source: target.terminalView, data: bytes[...])
            }
        }
    }

    /// Track when a terminal view gains focus by clicking in it directly.
    /// The focused terminal joins the broadcast group if broadcast is active.
    private func trackFocusChanges() {
        focusMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            DispatchQueue.main.async { self?.handleFocusChange() }
            return event
        }
    }

    private func handleFocusChange() {
        updateFocusIndicators()
    }

    deinit {
        if let monitor = selectionMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = keyMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = focusMonitor { NSEvent.removeMonitor(monitor) }
    }
}

// MARK: - Helper Types

/// Context menu for pairing/unpairing terminals. Uses tag-indexed closures
/// to avoid representedObject casting issues.
class PairContextMenu: NSMenu, NSMenuDelegate {
    private var actions: [Int: () -> Void] = [:]
    private var nextTag = 1

    init(sessionId: UUID, manager: SessionManager, controller: MainWindowController) {
        super.init(title: "")

        let others = manager.sessions.filter { $0.id != sessionId }
        let groups = manager.pairings(for: sessionId)

        // Header
        let header = NSMenuItem(title: "Pair with...", action: nil, keyEquivalent: "")
        header.isEnabled = false
        addItem(header)

        // Each other terminal — toggle pair/unpair
        for other in others {
            let paired = groups.contains { $0.memberIds.contains(other.id) }
            let prefix = paired ? "\u{2713} " : "    "
            let tag = nextTag
            nextTag += 1

            let otherId = other.id
            actions[tag] = { [weak manager, weak controller] in
                guard let manager, let controller else { return }
                let currentGroups = manager.pairings(for: sessionId)
                if let group = currentGroups.first(where: { $0.memberIds.contains(otherId) }) {
                    manager.removePairing(group.id)
                } else {
                    manager.createPairing(between: [sessionId, otherId])
                }
                controller.updateAllPairingIndicators()
                controller.hideSelectionBar()
            }

            let item = NSMenuItem(title: "\(prefix)\(other.label)", action: #selector(runAction(_:)), keyEquivalent: "")
            item.target = self
            item.tag = tag
            addItem(item)
        }

        // Unpair all
        if !groups.isEmpty {
            addItem(.separator())
            let tag = nextTag
            nextTag += 1
            actions[tag] = { [weak manager, weak controller] in
                guard let manager, let controller else { return }
                manager.unpairAll(sessionId: sessionId)
                controller.updateAllPairingIndicators()
                controller.hideSelectionBar()
            }
            let item = NSMenuItem(title: "Unpair All", action: #selector(runAction(_:)), keyEquivalent: "")
            item.target = self
            item.tag = tag
            addItem(item)
        }

        // Broadcast section
        addItem(.separator())
        let inBroadcast = controller.broadcastTargets.contains(sessionId)
        let bcTag = nextTag
        nextTag += 1
        actions[bcTag] = { [weak controller] in
            guard let controller else { return }
            if controller.broadcastTargets.contains(sessionId) {
                controller.broadcastTargets.remove(sessionId)
            } else {
                controller.broadcastTargets.insert(sessionId)
            }
            controller.updateFocusIndicators()
        }
        let bcPrefix = inBroadcast ? "\u{2713} " : "    "
        let bcItem = NSMenuItem(title: "\(bcPrefix)Broadcast Input", action: #selector(runAction(_:)), keyEquivalent: "")
        bcItem.target = self
        bcItem.tag = bcTag
        addItem(bcItem)

        if !controller.broadcastTargets.isEmpty {
            let clearTag = nextTag
            nextTag += 1
            actions[clearTag] = { [weak controller] in
                guard let controller else { return }
                controller.broadcastTargets.removeAll()
                controller.updateFocusIndicators()
            }
            let clearItem = NSMenuItem(title: "Clear Broadcast Group", action: #selector(runAction(_:)), keyEquivalent: "")
            clearItem.target = self
            clearItem.tag = clearTag
            addItem(clearItem)
        }
    }

    required init(coder: NSCoder) { fatalError() }

    @objc func runAction(_ sender: NSMenuItem) {
        actions[sender.tag]?()
    }
}

// MARK: - Selection Action Bar (multi-target with popover checkboxes)

class SelectionActionBar: NSView {
    let sourceId: UUID
    private let allTargets: [TerminalSession]
    private var activeTargets: Set<UUID>
    private let onSend: ([TerminalSession]) -> Void
    private let onSendAndRun: ([TerminalSession]) -> Void
    private let summaryLabel = NSTextField(labelWithString: "")
    private var popover: NSPopover?
    private var checkboxes: [UUID: NSButton] = [:]

    private var selectedTargets: [TerminalSession] {
        allTargets.filter { activeTargets.contains($0.id) }
    }

    init(sourceId: UUID, allTargets: [TerminalSession], defaultActive: Set<UUID>,
         onSend: @escaping ([TerminalSession]) -> Void, onSendAndRun: @escaping ([TerminalSession]) -> Void) {
        self.sourceId = sourceId
        self.allTargets = allTargets
        self.activeTargets = defaultActive
        self.onSend = onSend
        self.onSendAndRun = onSendAndRun
        super.init(frame: .zero)

        wantsLayer = true
        layer?.backgroundColor = Theme.bgTertiary.cgColor
        layer?.cornerRadius = 8
        layer?.borderColor = Theme.border.cgColor
        layer?.borderWidth = 1

        shadow = NSShadow()
        layer?.shadowColor = NSColor.black.withAlphaComponent(0.4).cgColor
        layer?.shadowOffset = NSSize(width: 0, height: -2)
        layer?.shadowRadius = 6
        layer?.shadowOpacity = 1

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 3
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        // Summary label + dropdown button
        updateSummary()
        summaryLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        summaryLabel.textColor = Theme.textPrimary
        summaryLabel.isSelectable = false

        let dropBtn = CallbackButton(title: " \u{25BE} ", action: { [weak self] in
            self?.showPopover()
        })
        dropBtn.font = NSFont.systemFont(ofSize: 11, weight: .bold)
        dropBtn.isBordered = false
        dropBtn.contentTintColor = Theme.textSecondary

        let sendBtn = CallbackButton(title: " Send ", action: { [weak self] in
            guard let self else { return }
            self.onSend(self.selectedTargets)
        })
        sendBtn.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        sendBtn.isBordered = false
        sendBtn.contentTintColor = Theme.accentGold

        let runBtn = CallbackButton(title: " Run ", action: { [weak self] in
            guard let self else { return }
            self.onSendAndRun(self.selectedTargets)
        })
        runBtn.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        runBtn.isBordered = false
        runBtn.contentTintColor = Theme.accentGreen

        let hint = NSTextField(labelWithString: " \u{2318}\u{21A9}")
        hint.font = NSFont.systemFont(ofSize: 10)
        hint.textColor = Theme.textMuted

        stack.addArrangedSubview(summaryLabel)
        stack.addArrangedSubview(dropBtn)
        stack.addArrangedSubview(makeSeparator())
        stack.addArrangedSubview(sendBtn)
        stack.addArrangedSubview(makeSeparator())
        stack.addArrangedSubview(runBtn)
        stack.addArrangedSubview(hint)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    var hasActivePopover: Bool {
        popover?.isShown ?? false
    }

    private func updateSummary() {
        let names = allTargets.filter { activeTargets.contains($0.id) }.map(\.label)
        let text = names.isEmpty ? "no targets" : names.joined(separator: ", ")
        summaryLabel.stringValue = " \(text) "
    }

    private func showPopover() {
        popover?.close()

        let vc = NSViewController()
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: CGFloat(allTargets.count) * 28 + 16))
        container.wantsLayer = true
        vc.view = container

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
        ])

        checkboxes.removeAll()
        for target in allTargets {
            let cb = NSButton(checkboxWithTitle: target.label, target: nil, action: nil)
            cb.font = NSFont.systemFont(ofSize: 12)
            cb.state = activeTargets.contains(target.id) ? .on : .off
            let targetId = target.id
            BlockTarget.shared.register(cb) { [weak self] in
                guard let self else { return }
                if self.activeTargets.contains(targetId) {
                    self.activeTargets.remove(targetId)
                    cb.state = .off
                } else {
                    self.activeTargets.insert(targetId)
                    cb.state = .on
                }
                self.updateSummary()
            }
            checkboxes[target.id] = cb
            stack.addArrangedSubview(cb)
        }

        let pop = NSPopover()
        pop.contentViewController = vc
        pop.behavior = .transient
        pop.show(relativeTo: summaryLabel.bounds, of: summaryLabel, preferredEdge: .maxY)
        popover = pop
    }

    private func makeSeparator() -> NSView {
        let sep = NSView()
        sep.wantsLayer = true
        sep.layer?.backgroundColor = Theme.border.cgColor
        sep.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            sep.widthAnchor.constraint(equalToConstant: 1),
            sep.heightAnchor.constraint(equalToConstant: 16),
        ])
        return sep
    }
}
