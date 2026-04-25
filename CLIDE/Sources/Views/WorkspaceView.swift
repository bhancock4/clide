import SwiftUI

struct WorkspaceView: View {
    @ObservedObject var manager: SessionManager
    @Binding var splitVisible: Bool
    let onHome: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Main terminal area
            HSplitView {
                // Main panel
                VStack(spacing: 0) {
                    mainHeader
                    mainTerminalArea
                }
                .frame(minWidth: 300)

                // Split panel (secondary)
                if splitVisible {
                    VStack(spacing: 0) {
                        secondaryHeader
                        secondaryTerminalArea
                    }
                    .frame(minWidth: 200)
                }
            }
        }
        .background(Color(red: 0.051, green: 0.067, blue: 0.090))
    }

    // MARK: - Main Panel

    private var mainHeader: some View {
        HStack(spacing: 0) {
            TabBar(
                sessions: manager.mainSessions,
                activeId: manager.activeMainId,
                onSelect: { manager.setActive($0, panel: .main) },
                onClose: { closeAndCheck($0) },
                onRename: { manager.moveToPanel($0, newPanel: .secondary); splitVisible = true }
            )

            Spacer()

            HStack(spacing: 4) {
                ToolbarButton(icon: "rectangle.split.2x1", tooltip: "Split View (Cmd+\\)") {
                    toggleSplit()
                }
                ToolbarButton(icon: "plus", tooltip: "New Terminal (Cmd+N)") {
                    manager.createSession(label: "Terminal", panel: .main)
                }
                ToolbarButton(icon: "gearshape", tooltip: "Settings (Cmd+,)") {
                    onOpenSettings()
                }
                ToolbarButton(icon: "house", tooltip: "Home") {
                    onHome()
                }
            }
            .padding(.trailing, 8)
        }
        .frame(height: 36)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    private var mainTerminalArea: some View {
        Group {
            if let session = manager.activeSession(for: .main) {
                TerminalViewWrapper(session: session)
                    .id(session.id) // Force view recreation on tab switch
            } else {
                Color(red: 0.051, green: 0.067, blue: 0.090)
            }
        }
    }

    // MARK: - Secondary Panel

    private var secondaryHeader: some View {
        HStack(spacing: 0) {
            TabBar(
                sessions: manager.secondarySessions,
                activeId: manager.activeSecondaryId,
                onSelect: { manager.setActive($0, panel: .secondary) },
                onClose: { closeSecondaryAndCheck($0) },
                onRename: { manager.moveToPanel($0, newPanel: .main) }
            )

            Spacer()

            HStack(spacing: 4) {
                ToolbarButton(icon: "plus", tooltip: "New Terminal (Cmd+Shift+N)") {
                    manager.createSession(label: "Terminal", panel: .secondary)
                }
                ToolbarButton(icon: "xmark", tooltip: "Close Split") {
                    splitVisible = false
                }
            }
            .padding(.trailing, 8)
        }
        .frame(height: 36)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
    }

    private var secondaryTerminalArea: some View {
        Group {
            if let session = manager.activeSession(for: .secondary) {
                TerminalViewWrapper(session: session)
                    .id(session.id)
            } else {
                Color(red: 0.051, green: 0.067, blue: 0.090)
            }
        }
    }

    // MARK: - Actions

    private func toggleSplit() {
        if splitVisible {
            splitVisible = false
        } else {
            splitVisible = true
            if manager.secondarySessions.isEmpty {
                manager.createSession(label: "Terminal", panel: .secondary)
            }
        }
    }

    private func closeAndCheck(_ id: UUID) {
        manager.closeSession(id)
        if !manager.hasAnySessions { onHome() }
    }

    private func closeSecondaryAndCheck(_ id: UUID) {
        manager.closeSession(id)
        if manager.secondarySessions.isEmpty { splitVisible = false }
        if !manager.hasAnySessions { onHome() }
    }
}

struct ToolbarButton: View {
    let icon: String
    let tooltip: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}
