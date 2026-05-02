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

        if let colorHex = fontColor, let nsColor = NSColor.fromHex(colorHex) {
            tv.nativeForegroundColor = nsColor
        } else {
            tv.nativeForegroundColor = NSColor(red: 0.90, green: 0.93, blue: 0.95, alpha: 1.0)
        }
        tv.nativeBackgroundColor = NSColor(red: 0.051, green: 0.067, blue: 0.090, alpha: 1.0)

        tv.processDelegate = delegate

        self.terminalView = tv
        self.processDelegate = delegate
        delegate.session = self

        let shellPath = shell ?? ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let shellIdiom = "-" + (shellPath as NSString).lastPathComponent
        let workingDir = cwd ?? FileManager.default.homeDirectoryForCurrentUser.path

        FileManager.default.changeCurrentDirectoryPath(workingDir)
        tv.startProcess(executable: shellPath, execName: shellIdiom)

        if !command.isEmpty {
            let fullCommand: String
            if args.isEmpty {
                fullCommand = command
            } else {
                fullCommand = ([command] + args).joined(separator: " ")
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak tv] in
                guard let tv else { return }
                let bytes = Array((fullCommand + "\n").utf8)
                tv.send(source: tv, data: bytes[...])
            }
        }
    }

    func sendInput(_ text: String) {
        terminalView.send(txt: text)
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
