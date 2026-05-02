import AppKit

/// A settings sheet presented as a window-modal sheet.
class SettingsPanel {
    static func show(in window: NSWindow, settings: inout AppSettings, onSave: @escaping (AppSettings) -> Void, onSaveCurrentLayout: (() -> Void)? = nil) {
        var editedSettings = settings
        let layoutCount = settings.layouts?.count ?? 0
        let panelHeight = 460 + CGFloat(layoutCount) * 22

        let sheet = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: panelHeight),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        sheet.title = "CLIDE Settings"

        let contentView = NSView(frame: sheet.contentView!.bounds)
        contentView.wantsLayer = true
        sheet.contentView = contentView

        var y: CGFloat = panelHeight - 40
        let leftMargin: CGFloat = 20
        let fieldWidth: CGFloat = 420

        // Title
        let title = NSTextField(labelWithString: "Settings")
        title.font = NSFont.monospacedSystemFont(ofSize: 16, weight: .bold)
        title.textColor = Theme.accentGold
        title.frame = NSRect(x: leftMargin, y: y, width: fieldWidth, height: 22)
        contentView.addSubview(title)
        y -= 36

        // Default Working Directory
        let cwdLabel = NSTextField(labelWithString: "Default Working Directory")
        cwdLabel.font = Theme.fontSmall
        cwdLabel.textColor = .secondaryLabelColor
        cwdLabel.frame = NSRect(x: leftMargin, y: y, width: fieldWidth, height: 18)
        contentView.addSubview(cwdLabel)
        y -= 26

        let cwdField = NSTextField()
        cwdField.font = Theme.font
        cwdField.stringValue = editedSettings.defaultCwd ?? ""
        cwdField.placeholderString = "/Users/you/Code"
        cwdField.frame = NSRect(x: leftMargin, y: y, width: 330, height: 24)
        contentView.addSubview(cwdField)

        let browseBtn = NSButton(title: "Browse...", target: nil, action: nil)
        browseBtn.frame = NSRect(x: 360, y: y, width: 80, height: 24)
        contentView.addSubview(browseBtn)
        browseBtn.target = BlockTarget.shared
        browseBtn.action = #selector(BlockTarget.run)
        BlockTarget.shared.register(browseBtn) {
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            if panel.runModal() == .OK, let url = panel.url {
                cwdField.stringValue = url.path
            }
        }
        y -= 28

        // Prompt for directory checkbox
        let promptCheck = NSButton(checkboxWithTitle: "Prompt for directory on each new terminal", target: nil, action: nil)
        promptCheck.font = Theme.fontSmall
        promptCheck.state = editedSettings.promptForDirectory == true ? .on : .off
        promptCheck.frame = NSRect(x: leftMargin, y: y, width: fieldWidth, height: 20)
        contentView.addSubview(promptCheck)
        y -= 30

        // Font Size
        let fsLabel = NSTextField(labelWithString: "Font Size")
        fsLabel.font = Theme.fontSmall
        fsLabel.textColor = .secondaryLabelColor
        fsLabel.frame = NSRect(x: leftMargin, y: y, width: 100, height: 18)
        contentView.addSubview(fsLabel)

        // Font Color
        let fcLabel = NSTextField(labelWithString: "Font Color")
        fcLabel.font = Theme.fontSmall
        fcLabel.textColor = .secondaryLabelColor
        fcLabel.frame = NSRect(x: 160, y: y, width: 100, height: 18)
        contentView.addSubview(fcLabel)
        y -= 28

        let fsField = NSTextField()
        fsField.font = Theme.font
        fsField.stringValue = "\(editedSettings.fontSize)"
        fsField.frame = NSRect(x: leftMargin, y: y, width: 60, height: 24)
        contentView.addSubview(fsField)

        let colorWell = NSColorWell()
        colorWell.frame = NSRect(x: 160, y: y, width: 40, height: 24)
        if let hex = editedSettings.fontColor, let c = NSColor.fromHex(hex) {
            colorWell.color = c
        } else {
            colorWell.color = NSColor(red: 0.9, green: 0.93, blue: 0.95, alpha: 1.0)
        }
        contentView.addSubview(colorWell)

        let resetColorBtn = NSButton(title: "Reset", target: nil, action: nil)
        resetColorBtn.font = Theme.fontTiny
        resetColorBtn.frame = NSRect(x: 210, y: y, width: 50, height: 24)
        contentView.addSubview(resetColorBtn)
        BlockTarget.shared.register(resetColorBtn) {
            colorWell.color = NSColor(red: 0.9, green: 0.93, blue: 0.95, alpha: 1.0)
        }
        y -= 36

        // Default Shell
        let shellLabel = NSTextField(labelWithString: "Default Shell (blank = system default)")
        shellLabel.font = Theme.fontSmall
        shellLabel.textColor = .secondaryLabelColor
        shellLabel.frame = NSRect(x: leftMargin, y: y, width: fieldWidth, height: 18)
        contentView.addSubview(shellLabel)
        y -= 26

        let shellField = NSTextField()
        shellField.font = Theme.font
        shellField.stringValue = editedSettings.defaultShell ?? ""
        shellField.placeholderString = "/bin/zsh"
        shellField.frame = NSRect(x: leftMargin, y: y, width: fieldWidth, height: 24)
        contentView.addSubview(shellField)
        y -= 44

        // Layouts section
        let layoutLabel = NSTextField(labelWithString: "Layouts")
        layoutLabel.font = Theme.fontSmall
        layoutLabel.textColor = .secondaryLabelColor
        layoutLabel.frame = NSRect(x: leftMargin, y: y, width: fieldWidth, height: 18)
        contentView.addSubview(layoutLabel)
        y -= 24

        // List existing layouts
        let layouts = editedSettings.layouts ?? []
        for (idx, layout) in layouts.enumerated() {
            let defaultMark = layout.isDefault ? " (default)" : ""
            let nameLabel = NSTextField(labelWithString: "\(layout.name)\(defaultMark)")
            nameLabel.font = Theme.fontSmall
            nameLabel.textColor = layout.isDefault ? Theme.accentGold : Theme.textPrimary
            nameLabel.frame = NSRect(x: leftMargin + 4, y: y, width: 200, height: 20)
            contentView.addSubview(nameLabel)

            if !layout.isDefault {
                let defaultBtn = NSButton(title: "Set Default", target: nil, action: nil)
                defaultBtn.font = Theme.fontTiny
                defaultBtn.frame = NSRect(x: 220, y: y, width: 80, height: 20)
                contentView.addSubview(defaultBtn)
                BlockTarget.shared.register(defaultBtn) {
                    if editedSettings.layouts == nil { return }
                    for i in editedSettings.layouts!.indices {
                        editedSettings.layouts![i].isDefault = (i == idx)
                    }
                    try? editedSettings.save() // Settings panel saves are best-effort during interaction
                    onSave(editedSettings)
                    window.endSheet(sheet)
                }
            }

            let editBtn = NSButton(title: "Edit", target: nil, action: nil)
            editBtn.font = Theme.fontTiny
            editBtn.frame = NSRect(x: 310, y: y, width: 45, height: 20)
            contentView.addSubview(editBtn)
            BlockTarget.shared.register(editBtn) {
                LayoutEditorViewController.show(in: sheet, layout: layout, tools: editedSettings.tools, onSave: { updated in
                    guard let i = editedSettings.layouts?.firstIndex(where: { $0.id == updated.id }) else { return }
                    if updated.isDefault {
                        for j in editedSettings.layouts!.indices { editedSettings.layouts![j].isDefault = false }
                    }
                    editedSettings.layouts![i] = updated
                    try? editedSettings.save() // Settings panel saves are best-effort during interaction
                    onSave(editedSettings)
                }, onDelete: { deleteId in
                    editedSettings.layouts?.removeAll { $0.id == deleteId }
                    try? editedSettings.save() // Settings panel saves are best-effort during interaction
                    onSave(editedSettings)
                })
            }

            let delBtn = NSButton(title: "✕", target: nil, action: nil)
            delBtn.font = Theme.fontTiny
            delBtn.frame = NSRect(x: 365, y: y, width: 24, height: 20)
            contentView.addSubview(delBtn)
            BlockTarget.shared.register(delBtn) {
                editedSettings.layouts?.removeAll { $0.id == layout.id }
                try? editedSettings.save() // Settings panel saves are best-effort during interaction
                onSave(editedSettings)
                window.endSheet(sheet)
            }

            y -= 22
        }

        // Save current layout button
        if let saveCurrent = onSaveCurrentLayout {
            let saveCurrentBtn = NSButton(title: "Save Current Layout...", target: nil, action: nil)
            saveCurrentBtn.font = Theme.fontSmall
            saveCurrentBtn.frame = NSRect(x: leftMargin, y: y, width: 160, height: 22)
            contentView.addSubview(saveCurrentBtn)
            BlockTarget.shared.register(saveCurrentBtn) {
                window.endSheet(sheet)
                saveCurrent()
            }
            y -= 24
        }

        // New layout button
        let newLayoutBtn = NSButton(title: "+ New Layout...", target: nil, action: nil)
        newLayoutBtn.font = Theme.fontSmall
        newLayoutBtn.frame = NSRect(x: leftMargin, y: y, width: 120, height: 22)
        contentView.addSubview(newLayoutBtn)
        BlockTarget.shared.register(newLayoutBtn) {
            LayoutEditorViewController.show(in: sheet, layout: nil, tools: editedSettings.tools, onSave: { newLayout in
                if editedSettings.layouts == nil { editedSettings.layouts = [] }
                var layout = newLayout
                if layout.isDefault {
                    for i in editedSettings.layouts!.indices { editedSettings.layouts![i].isDefault = false }
                }
                editedSettings.layouts!.append(layout)
                try? editedSettings.save() // Settings panel saves are best-effort during interaction
                onSave(editedSettings)
            })
        }
        y -= 36

        // Buttons
        let cancelBtn = NSButton(title: "Cancel", target: nil, action: nil)
        cancelBtn.frame = NSRect(x: 290, y: y, width: 80, height: 30)
        cancelBtn.keyEquivalent = "\u{1b}" // Escape
        contentView.addSubview(cancelBtn)
        BlockTarget.shared.register(cancelBtn) {
            window.endSheet(sheet)
        }

        let saveBtn = NSButton(title: "Save", target: nil, action: nil)
        saveBtn.frame = NSRect(x: 380, y: y, width: 60, height: 30)
        saveBtn.keyEquivalent = "\r" // Enter
        saveBtn.bezelStyle = .rounded
        contentView.addSubview(saveBtn)
        BlockTarget.shared.register(saveBtn) {
            editedSettings.defaultCwd = cwdField.stringValue.isEmpty ? nil : cwdField.stringValue
            editedSettings.promptForDirectory = promptCheck.state == .on ? true : nil
            editedSettings.fontSize = Int(fsField.stringValue) ?? 14
            editedSettings.defaultShell = shellField.stringValue.isEmpty ? nil : shellField.stringValue

            let c = colorWell.color.usingColorSpace(.sRGB) ?? colorWell.color
            let hex = String(format: "#%02x%02x%02x",
                             Int(c.redComponent * 255),
                             Int(c.greenComponent * 255),
                             Int(c.blueComponent * 255))
            editedSettings.fontColor = hex

            do {
                try editedSettings.save()
            } catch {
                let alert = NSAlert()
                alert.messageText = "Failed to save settings"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.runModal()
            }
            onSave(editedSettings)
            window.endSheet(sheet)
        }

        window.beginSheet(sheet)
    }
}

/// Helper to wire NSButton actions to closures without subclassing.
class BlockTarget: NSObject {
    static let shared = BlockTarget()
    private var blocks: [ObjectIdentifier: () -> Void] = [:]

    func register(_ sender: NSButton, block: @escaping () -> Void) {
        blocks[ObjectIdentifier(sender)] = block
        sender.target = self
        sender.action = #selector(run(_:))
    }

    @objc func run(_ sender: Any?) {
        guard let sender = sender as? NSButton else { return }
        blocks[ObjectIdentifier(sender)]?()
    }
}
