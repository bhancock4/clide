import Foundation
import SwiftTerm
import AppKit

/// Delegate that monitors process exit and notifies the session.
class TerminalProcessDelegate: NSObject, LocalProcessTerminalViewDelegate {
    weak var session: TerminalSession?

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        DispatchQueue.main.async { [weak self] in
            self?.session?.isAlive = false
        }
    }
}

/// Represents a single terminal session with its PTY and view.
class TerminalSession: Identifiable, ObservableObject {
    let id = UUID()
    @Published var label: String
    /// True if the user manually renamed this tab (don't auto-renumber it).
    var hasCustomLabel = false
    let command: String
    let args: [String]
    @Published var column: Int
    @Published var isAlive: Bool = true

    let terminalView: LocalProcessTerminalView
    private let processDelegate: TerminalProcessDelegate

    init(label: String, command: String, args: [String], column: Int, cwd: String?, shell: String?, fontSize: Int, fontColor: String?) {
        self.label = label
        self.command = command
        self.args = args
        self.column = column

        let tv = LocalProcessTerminalView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        let delegate = TerminalProcessDelegate()

        let font = NSFont.monospacedSystemFont(ofSize: CGFloat(fontSize), weight: .regular)
        tv.font = font
        tv.configureNativeColors()

        tv.nativeForegroundColor = Theme.terminalForeground
        tv.nativeBackgroundColor = Theme.terminalBackground

        tv.processDelegate = delegate

        self.terminalView = tv
        self.processDelegate = delegate
        delegate.session = self

        // Validate shell path — fall back to /bin/zsh if invalid
        let requestedShell = shell ?? ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let shellPath = FileManager.default.isExecutableFile(atPath: requestedShell) ? requestedShell : "/bin/zsh"
        let shellIdiom = "-" + (shellPath as NSString).lastPathComponent

        // Validate working directory — fall back to home if invalid
        let requestedCwd = cwd ?? FileManager.default.homeDirectoryForCurrentUser.path
        let workingDir: String
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: requestedCwd, isDirectory: &isDir), isDir.boolValue {
            workingDir = requestedCwd
        } else {
            workingDir = FileManager.default.homeDirectoryForCurrentUser.path
        }

        FileManager.default.changeCurrentDirectoryPath(workingDir)
        tv.startProcess(executable: shellPath, execName: shellIdiom)

        if !command.isEmpty {
            // Shell-escape each argument to prevent injection
            let escapedParts = ([command] + args).map { Self.shellEscape($0) }
            let fullCommand = escapedParts.joined(separator: " ")

            // Wait for shell prompt by checking for output, with a fallback timeout
            Self.waitForShellReady(tv: tv, command: fullCommand)
        }
    }

    func sendInput(_ text: String) {
        terminalView.send(txt: text)
    }

    /// Shell-escape a string for safe inclusion in a command line.
    static func shellEscape(_ arg: String) -> String {
        // If the string is simple (alphanumeric, hyphens, dots, slashes), no escaping needed
        let safe = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._/=:@"))
        if !arg.isEmpty && arg.unicodeScalars.allSatisfy({ safe.contains($0) }) {
            return arg
        }
        // Wrap in single quotes, escaping any embedded single quotes
        return "'" + arg.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Send a command after a short delay for the shell to initialize.
    /// Uses 0.3s which is long enough for most shell inits but shorter
    /// than the previous 0.5s fixed delay.
    private static func waitForShellReady(tv: LocalProcessTerminalView, command: String, attempt: Int = 0) {
        let delay: Double = attempt == 0 ? 0.3 : 0.5
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak tv] in
            guard let tv else { return }
            let bytes = Array((command + "\n").utf8)
            tv.send(source: tv, data: bytes[...])
        }
    }
}

// MARK: - NSColor hex helper

extension NSColor {
    static func fromHex(_ hex: String) -> NSColor? {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return nil }
        let r = CGFloat((val >> 16) & 0xFF) / 255.0
        let g = CGFloat((val >> 8) & 0xFF) / 255.0
        let b = CGFloat(val & 0xFF) / 255.0
        return NSColor(red: r, green: g, blue: b, alpha: 1.0)
    }
}
