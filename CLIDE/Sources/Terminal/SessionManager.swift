import Foundation
import SwiftUI

/// Manages all terminal sessions across panels.
class SessionManager: ObservableObject {
    @Published var sessions: [TerminalSession] = []
    @Published var activeMainId: UUID?
    @Published var activeSecondaryId: UUID?

    var settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
    }

    // MARK: - Session Lifecycle

    @discardableResult
    func createSession(
        label: String,
        command: String = "",
        args: [String] = [],
        panel: TerminalSession.Panel = .main,
        cwd: String? = nil
    ) -> TerminalSession {
        let session = TerminalSession(
            label: label,
            command: command,
            args: args,
            panel: panel,
            cwd: cwd ?? settings.defaultCwd,
            shell: settings.defaultShell,
            fontSize: settings.fontSize,
            fontColor: settings.fontColor
        )

        sessions.append(session)

        switch panel {
        case .main:
            activeMainId = session.id
        case .secondary:
            activeSecondaryId = session.id
        }

        return session
    }

    func closeSession(_ id: UUID) {
        sessions.removeAll { $0.id == id }

        if activeMainId == id {
            activeMainId = mainSessions.first?.id
        }
        if activeSecondaryId == id {
            activeSecondaryId = secondarySessions.first?.id
        }
    }

    // MARK: - Active Session

    func setActive(_ id: UUID, panel: TerminalSession.Panel) {
        switch panel {
        case .main:
            activeMainId = id
        case .secondary:
            activeSecondaryId = id
        }
    }

    func activeSession(for panel: TerminalSession.Panel) -> TerminalSession? {
        let id = panel == .main ? activeMainId : activeSecondaryId
        guard let id else { return nil }
        return sessions.first { $0.id == id }
    }

    // MARK: - Panel Queries

    var mainSessions: [TerminalSession] {
        sessions.filter { $0.panel == .main }
    }

    var secondarySessions: [TerminalSession] {
        sessions.filter { $0.panel == .secondary }
    }

    var hasAnySessions: Bool {
        !sessions.isEmpty
    }

    // MARK: - Tab Navigation

    func cycleTab(panel: TerminalSession.Panel, forward: Bool) {
        let panelSessions = panel == .main ? mainSessions : secondarySessions
        guard panelSessions.count > 1 else { return }

        let activeId = panel == .main ? activeMainId : activeSecondaryId
        let currentIndex = panelSessions.firstIndex { $0.id == activeId } ?? 0
        let nextIndex: Int
        if forward {
            nextIndex = (currentIndex + 1) % panelSessions.count
        } else {
            nextIndex = (currentIndex - 1 + panelSessions.count) % panelSessions.count
        }
        setActive(panelSessions[nextIndex].id, panel: panel)
    }

    func selectTab(index: Int, panel: TerminalSession.Panel) {
        let panelSessions = panel == .main ? mainSessions : secondarySessions
        guard index < panelSessions.count else { return }
        setActive(panelSessions[index].id, panel: panel)
    }

    func moveToPanel(_ id: UUID, newPanel: TerminalSession.Panel) {
        guard let session = sessions.first(where: { $0.id == id }) else { return }
        session.panel = newPanel
        setActive(id, panel: newPanel)
    }

    // MARK: - Session Persistence

    func saveSession() {
        let saved = SavedSession(
            terminals: sessions.map { session in
                SavedTerminal(
                    label: session.label,
                    command: session.command,
                    args: session.args,
                    panel: session.panel.rawValue,
                    cwd: nil
                )
            },
            sidebarVisible: false,
            splitVisible: !secondarySessions.isEmpty
        )
        try? saved.save()
    }

    func restoreSession() {
        let saved = SavedSession.load()
        for terminal in saved.terminals {
            let panel: TerminalSession.Panel = terminal.panel == "secondary" ? .secondary : .main
            createSession(
                label: terminal.label,
                command: terminal.command,
                args: terminal.args,
                panel: panel,
                cwd: terminal.cwd
            )
        }
        SavedSession.clear()
    }
}
