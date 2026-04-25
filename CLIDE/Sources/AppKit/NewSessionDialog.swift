import AppKit

/// Prompts the user for a working directory when launching a new session.
struct NewSessionDialog {
    /// Shows a dialog asking where to start the session.
    /// Returns the chosen directory path, or nil if cancelled.
    static func prompt(defaultCwd: String?, in window: NSWindow) -> String? {
        let startDir = defaultCwd ?? FileManager.default.homeDirectoryForCurrentUser.path

        let alert = NSAlert()
        alert.messageText = "Working Directory"
        alert.informativeText = "Start this session in:"

        // Accessory view with path field + browse button
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 60))

        let pathField = NSTextField()
        pathField.font = Theme.font
        pathField.stringValue = startDir
        pathField.frame = NSRect(x: 0, y: 30, width: 270, height: 24)
        container.addSubview(pathField)

        let browseBtn = NSButton(title: "Browse...", target: nil, action: nil)
        browseBtn.frame = NSRect(x: 278, y: 30, width: 80, height: 24)
        container.addSubview(browseBtn)
        BlockTarget.shared.register(browseBtn) {
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.directoryURL = URL(fileURLWithPath: pathField.stringValue)
            if panel.runModal() == .OK, let url = panel.url {
                pathField.stringValue = url.path
            }
        }

        let createCheck = NSButton(checkboxWithTitle: "Create directory if it doesn't exist", target: nil, action: nil)
        createCheck.font = Theme.fontSmall
        createCheck.frame = NSRect(x: 0, y: 0, width: 360, height: 20)
        container.addSubview(createCheck)

        alert.accessoryView = container
        alert.addButton(withTitle: "Launch")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return nil }

        let dir = pathField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !dir.isEmpty else { return startDir }

        // Create directory if requested
        if createCheck.state == .on {
            try? FileManager.default.createDirectory(
                atPath: dir,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        return dir
    }
}
