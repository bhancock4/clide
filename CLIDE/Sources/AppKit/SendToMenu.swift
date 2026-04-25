import AppKit
import SwiftTerm

/// Dynamic context menu for sending selected text between terminals.
/// Rebuilds its items each time the menu opens to reflect current terminals.
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

        let targets = manager.sessions.filter { $0.id != source.id }
        guard !targets.isEmpty else {
            let noTargets = NSMenuItem(title: "No other terminals", action: nil, keyEquivalent: "")
            noTargets.isEnabled = false
            menu.addItem(noTargets)
            return
        }

        // If in split mode, show the split partner first as a quick action
        let otherPanel: TerminalSession.Panel = source.panel == .main ? .secondary : .main
        if let partner = manager.activeSession(for: otherPanel) {
            let pasteItem = NSMenuItem(title: "Paste in \(partner.label)", action: #selector(sendAction(_:)), keyEquivalent: "")
            pasteItem.target = self
            pasteItem.representedObject = SendAction(source: source, target: partner, execute: false, controller: controller)
            pasteItem.image = dotImage(for: partner.command)
            menu.addItem(pasteItem)

            if targets.count > 1 {
                menu.addItem(.separator())
            }
        }

        // All other targets
        let otherTargets = targets.filter { $0.id != manager.activeSession(for: otherPanel)?.id }
        if !otherTargets.isEmpty {
            let header = NSMenuItem(title: "Paste in...", action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)

            for target in otherTargets {
                let item = NSMenuItem(title: "  \(target.label)", action: #selector(sendAction(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = SendAction(source: source, target: target, execute: false, controller: controller)
                item.image = dotImage(for: target.command)
                menu.addItem(item)
            }
        }
    }

    @objc private func sendAction(_ sender: NSMenuItem) {
        guard let action = sender.representedObject as? SendAction else { return }
        action.controller?.sendSelection(from: action.source, to: action.target, execute: action.execute)
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

/// Holds the context for a send action.
private class SendAction {
    let source: TerminalSession
    let target: TerminalSession
    let execute: Bool
    weak var controller: MainWindowController?

    init(source: TerminalSession, target: TerminalSession, execute: Bool, controller: MainWindowController) {
        self.source = source
        self.target = target
        self.execute = execute
        self.controller = controller
    }
}
