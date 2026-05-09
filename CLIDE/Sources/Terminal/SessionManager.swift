import Foundation
import SwiftUI

/// Manages all terminal sessions across columns.
class SessionManager: ObservableObject {
    @Published var sessions: [TerminalSession] = []
    @Published var activeIds: [Int: UUID] = [:]   // column index → active session
    @Published var columnCount: Int = 1
    @Published var pairingGroups: [PairingGroup] = []

    /// O(1) session lookup by ID
    private var sessionIndex: [UUID: TerminalSession] = [:]

    var settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
    }

    /// O(1) lookup by session ID
    func session(byId id: UUID) -> TerminalSession? {
        sessionIndex[id]
    }

    // MARK: - Session Lifecycle

    @discardableResult
    func createSession(
        label: String,
        command: String = "",
        args: [String] = [],
        column: Int = 0,
        cwd: String? = nil
    ) -> TerminalSession {
        let session = TerminalSession(
            label: label,
            command: command,
            args: args,
            column: column,
            cwd: cwd ?? settings.defaultCwd,
            shell: settings.defaultShell,
            fontSize: settings.fontSize,
            fontColor: settings.fontColor
        )
        sessions.append(session)
        sessionIndex[session.id] = session
        activeIds[column] = session.id
        return session
    }

    func closeSession(_ id: UUID) {
        guard let session = sessionIndex[id] else { return }
        let col = session.column
        sessions.removeAll { $0.id == id }
        sessionIndex.removeValue(forKey: id)

        if activeIds[col] == id {
            activeIds[col] = sessions(forColumn: col).first?.id
        }

        unpairAll(sessionId: id)
    }

    // MARK: - Active Session

    func setActive(_ id: UUID, column: Int) {
        activeIds[column] = id
    }

    func activeSession(forColumn col: Int) -> TerminalSession? {
        guard let id = activeIds[col] else { return nil }
        return sessions.first { $0.id == id }
    }

    // MARK: - Column Queries

    func sessions(forColumn col: Int) -> [TerminalSession] {
        sessions.filter { $0.column == col }
    }

    var hasAnySessions: Bool {
        !sessions.isEmpty
    }

    // MARK: - Column Management

    @discardableResult
    func addColumn() -> Int {
        let col = columnCount
        columnCount += 1
        return col
    }

    /// Insert a new column after the given index, shifting higher columns right.
    @discardableResult
    func insertColumn(after col: Int) -> Int {
        let newCol = col + 1
        // Shift sessions in columns >= newCol up by one
        for session in sessions where session.column >= newCol {
            session.column += 1
        }
        var newIds: [Int: UUID] = [:]
        for (key, val) in activeIds {
            if key < newCol { newIds[key] = val }
            else { newIds[key + 1] = val }
        }
        activeIds = newIds
        columnCount += 1
        return newCol
    }

    func removeColumn(_ col: Int) {
        // Remove sessions in this column
        sessions.removeAll { $0.column == col }
        activeIds.removeValue(forKey: col)

        // Shift higher columns down
        for session in sessions where session.column > col {
            session.column -= 1
        }
        var newIds: [Int: UUID] = [:]
        for (key, val) in activeIds {
            if key < col { newIds[key] = val }
            else if key > col { newIds[key - 1] = val }
        }
        activeIds = newIds
        columnCount = max(1, columnCount - 1)
    }

    // MARK: - Tab Navigation

    func cycleTab(column: Int, forward: Bool) {
        let colSessions = sessions(forColumn: column)
        guard colSessions.count > 1 else { return }

        let currentIndex = colSessions.firstIndex { $0.id == activeIds[column] } ?? 0
        let nextIndex: Int
        if forward {
            nextIndex = (currentIndex + 1) % colSessions.count
        } else {
            nextIndex = (currentIndex - 1 + colSessions.count) % colSessions.count
        }
        setActive(colSessions[nextIndex].id, column: column)
    }

    func selectTab(index: Int, column: Int) {
        let colSessions = sessions(forColumn: column)
        guard index < colSessions.count else { return }
        setActive(colSessions[index].id, column: column)
    }

    /// Global monotonically increasing counter — numbers are never reused.
    private var nextNumber: Int = 0

    func nextLabel(baseName: String) -> String {
        nextNumber += 1
        return "\(baseName) \(nextNumber)"
    }

    func moveToColumn(_ id: UUID, newColumn: Int) {
        guard let session = sessions.first(where: { $0.id == id }) else { return }
        session.column = newColumn
        setActive(id, column: newColumn)
    }

    // MARK: - Pairing

    struct PairingGroup: Identifiable, Codable {
        var id: UUID
        var color: String
        var memberIds: Set<UUID>
    }

    private let pairingColors = [
        "#e06c75", "#98c379", "#61afef", "#c678dd",
        "#e5c07b", "#56b6c2", "#be5046", "#d19a66"
    ]

    @discardableResult
    func createPairing(between ids: Set<UUID>, color: String? = nil) -> PairingGroup {
        // Check if these two sessions are already paired together
        if ids.count == 2 {
            for group in pairingGroups {
                if ids.isSubset(of: group.memberIds) {
                    return group  // already paired
                }
            }
        }
        // Pick a color not used by any existing group
        let c = color ?? nextUnusedColor()
        let group = PairingGroup(id: UUID(), color: c, memberIds: ids)
        pairingGroups.append(group)
        return group
    }

    private func nextUnusedColor() -> String {
        let usedColors = Set(pairingGroups.map(\.color))
        for color in pairingColors where !usedColors.contains(color) {
            return color
        }
        // All colors used — cycle with a suffix to differentiate
        return pairingColors[pairingGroups.count % pairingColors.count]
    }

    func removePairing(_ groupId: UUID) {
        pairingGroups.removeAll { $0.id == groupId }
    }

    func unpairAll(sessionId: UUID) {
        for i in pairingGroups.indices.reversed() {
            pairingGroups[i].memberIds.remove(sessionId)
            if pairingGroups[i].memberIds.count < 2 {
                pairingGroups.remove(at: i)
            }
        }
    }

    func pairings(for sessionId: UUID) -> [PairingGroup] {
        pairingGroups.filter { $0.memberIds.contains(sessionId) }
    }

    func pairedSessions(for sessionId: UUID) -> [TerminalSession] {
        let pairedIds = pairings(for: sessionId).flatMap(\.memberIds)
        let uniqueIds = Set(pairedIds).subtracting([sessionId])
        return sessions.filter { uniqueIds.contains($0.id) }
    }

    // MARK: - Layout Capture/Apply

    func captureLayout(name: String, windowFrame: NSRect? = nil) -> TerminalLayout {
        var layoutColumns: [LayoutColumn] = []
        for col in 0..<columnCount {
            let colSessions = sessions(forColumn: col)
            let terminals = colSessions.map {
                LayoutTerminal(label: $0.label, command: $0.command, args: $0.args)
            }
            layoutColumns.append(LayoutColumn(terminals: terminals))
        }
        let layoutPairings = pairingGroups.map { group in
            LayoutPairing(id: group.id, color: group.color, members: group.memberIds.compactMap { sid in
                guard let s = sessions.first(where: { $0.id == sid }) else { return nil }
                let row = sessions(forColumn: s.column).firstIndex(where: { $0.id == sid }) ?? 0
                return LayoutPosition(column: s.column, row: row)
            })
        }
        let frame: LayoutRect?
        if let f = windowFrame {
            frame = LayoutRect(x: f.origin.x, y: f.origin.y, width: f.size.width, height: f.size.height)
        } else {
            frame = nil
        }
        return TerminalLayout(name: name, columns: layoutColumns, pairings: layoutPairings, windowFrame: frame)
    }

    func applyLayout(_ layout: TerminalLayout, cwd: String) {
        for (colIdx, col) in layout.columns.enumerated() {
            while columnCount <= colIdx { _ = addColumn() }
            for terminal in col.terminals {
                // Use the tool name if a command is set, otherwise generate a unique name
                let baseName = terminal.command.isEmpty ? "Terminal" : terminal.label
                let label = nextLabel(baseName: baseName)
                createSession(
                    label: label,
                    command: terminal.command,
                    args: terminal.args,
                    column: colIdx,
                    cwd: cwd
                )
            }
        }
        // Restore pairings by position
        for pairing in layout.pairings {
            var group = PairingGroup(id: UUID(), color: pairing.color, memberIds: [])
            for pos in pairing.members {
                let colSessions = sessions(forColumn: pos.column)
                if pos.row < colSessions.count {
                    group.memberIds.insert(colSessions[pos.row].id)
                }
            }
            if group.memberIds.count >= 2 {
                pairingGroups.append(group)
            }
        }
    }

    // MARK: - Session Persistence

    func saveSession() {
        let saved = SavedSession(
            terminals: sessions.map { session in
                SavedTerminal(
                    label: session.label,
                    command: session.command,
                    args: session.args,
                    column: session.column,
                    cwd: nil
                )
            },
            columnCount: columnCount
        )
        do {
            try saved.save()
        } catch {
            // Log but don't crash on session save failure at quit time
            NSLog("CLIDE: Failed to save session: \(error.localizedDescription)")
        }
    }

    func restoreSession() {
        let saved = SavedSession.load()
        columnCount = max(1, saved.columnCount)
        for terminal in saved.terminals {
            createSession(
                label: terminal.label,
                command: terminal.command,
                args: terminal.args,
                column: terminal.column,
                cwd: terminal.cwd
            )
        }
        SavedSession.clear()
    }
}
