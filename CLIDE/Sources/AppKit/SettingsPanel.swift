import AppKit

/// A settings sheet presented as a window-modal sheet.
class SettingsPanel {
    static func show(in window: NSWindow, settings: inout AppSettings, onSave: @escaping (AppSettings) -> Void) {
        var editedSettings = settings

        let sheet = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        sheet.title = "CLIDE Settings"

        let contentView = NSView(frame: sheet.contentView!.bounds)
        contentView.wantsLayer = true
        sheet.contentView = contentView

        var y: CGFloat = 320
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

            try? editedSettings.save()
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
