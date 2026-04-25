import SwiftUI
import SwiftTerm

/// Wraps SwiftTerm's LocalProcessTerminalView for use in SwiftUI.
struct TerminalViewWrapper: NSViewRepresentable {
    let session: TerminalSession

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        return session.terminalView
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        // SwiftTerm handles its own updates
    }
}
