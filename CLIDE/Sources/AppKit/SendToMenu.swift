import AppKit
import SwiftTerm

/// Dynamic context menu for sending selected text between terminals.
class SendToMenu: NSMenu, NSMenuDelegate {
    weak var manager: SessionManager?
    weak var sourceSession: TerminalSession?
    weak var controller: MainWindowController?

    init(manager: SessionManager, sourceSession: TerminalSession, controller: MainWindowController) {
        self.manager = manager
        self.sourceSession = sourceSession
        self.controller = controller
        super.init(title: "")
        self.delegate = self
    }

    required init(coder: NSCoder) { fatalError() }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        guard let manager, let source = sourceSession, let controller else { return }

        let allTargets = manager.sessions.filter { $0.id != source.id }
        guard !allTargets.isEmpty else {
            let noTargets = NSMenuItem(title: "No other terminals", action: nil, keyEquivalent: "")
            noTargets.isEnabled = false
            menu.addItem(noTargets)
            return
        }

        // Paired terminals — bulk actions first
        let paired = manager.pairedSessions(for: source.id)
        if paired.count > 1 {
            let sendAllItem = NSMenuItem(title: "Send to All Paired (\(paired.count))", action: #selector(sendAction(_:)), keyEquivalent: "")
            sendAllItem.target = self
            sendAllItem.representedObject = SendAction(source: source, targets: paired, execute: false, controller: controller)
            menu.addItem(sendAllItem)

            let runAllItem = NSMenuItem(title: "Send & Run in All Paired (\(paired.count))", action: #selector(sendAction(_:)), keyEquivalent: "")
            runAllItem.target = self
            runAllItem.representedObject = SendAction(source: source, targets: paired, execute: true, controller: controller)
            menu.addItem(runAllItem)

            menu.addItem(.separator())
        }

        if !paired.isEmpty {
            let header = NSMenuItem(title: "Paired", action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)

            for target in paired {
                addTargetItems(menu: menu, source: source, target: target, controller: controller, indent: true)
            }
            menu.addItem(.separator())
        }

        // Other targets
        let pairedIds = Set(paired.map(\.id))
        let others = allTargets.filter { !pairedIds.contains($0.id) }

        if !others.isEmpty {
            // Active sessions from other columns first (by proximity)
            let otherColumnActives = (0..<manager.columnCount)
                .filter { $0 != source.column }
                .sorted(by: { abs($0 - source.column) < abs($1 - source.column) })
                .compactMap { manager.activeSession(forColumn: $0) }
                .filter { !pairedIds.contains($0.id) }

            for target in otherColumnActives {
                addTargetItems(menu: menu, source: source, target: target, controller: controller, indent: false)
            }

            let shownIds = Set(otherColumnActives.map(\.id))
            let remaining = others.filter { !shownIds.contains($0.id) }
            if !remaining.isEmpty && !otherColumnActives.isEmpty {
                menu.addItem(.separator())
            }
            for target in remaining {
                addTargetItems(menu: menu, source: source, target: target, controller: controller, indent: true)
            }
        }
    }

    private func addTargetItems(menu: NSMenu, source: TerminalSession, target: TerminalSession, controller: MainWindowController, indent: Bool) {
        let prefix = indent ? "  " : ""

        let sendItem = NSMenuItem(title: "\(prefix)Send to \(target.label)", action: #selector(sendAction(_:)), keyEquivalent: "")
        sendItem.target = self
        sendItem.representedObject = SendAction(source: source, targets: [target], execute: false, controller: controller)
        sendItem.image = dotImage(for: target.command)
        menu.addItem(sendItem)

        let runItem = NSMenuItem(title: "\(prefix)Send & Run in \(target.label)", action: #selector(sendAction(_:)), keyEquivalent: "")
        runItem.target = self
        runItem.representedObject = SendAction(source: source, targets: [target], execute: true, controller: controller)
        runItem.image = dotImage(for: target.command)
        menu.addItem(runItem)
    }

    @objc private func sendAction(_ sender: NSMenuItem) {
        guard let action = sender.representedObject as? SendAction else { return }
        for target in action.targets {
            action.controller?.sendSelection(from: action.source, to: target, execute: action.execute)
        }
    }

    private func dotImage(for command: String) -> NSImage {
        let color = NSColor.fromHex(commandColor(command)) ?? .gray
        let size = NSSize(width: 8, height: 8)
        let image = NSImage(size: size)
        image.lockFocus()
        color.setFill()
        NSBezierPath(ovalIn: NSRect(origin: .zero, size: size)).fill()
        image.unlockFocus()
        return image
    }

    private func commandColor(_ cmd: String) -> String {
        let defaults: [String: String] = [
            "claude": "#d97706", "gemini": "#2563eb", "aider": "#16a34a",
            "gh": "#6e40c9", "cursor": "#00b4d8",
        ]
        return defaults[cmd] ?? "#8b949e"
    }
}

private class SendAction {
    let source: TerminalSession
    let targets: [TerminalSession]
    let execute: Bool
    weak var controller: MainWindowController?

    init(source: TerminalSession, targets: [TerminalSession], execute: Bool, controller: MainWindowController) {
        self.source = source
        self.targets = targets
        self.execute = execute
        self.controller = controller
    }
}
