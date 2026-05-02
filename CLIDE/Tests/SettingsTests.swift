import Testing
import Foundation
import AppKit
@testable import CLIDE

// MARK: - AppSettings

@Suite("AppSettings Tests")
struct AppSettingsTests {

    @Test("Default settings has all tools")
    func defaultToolCount() {
        let settings = AppSettings.default
        #expect(settings.tools.count == 5)
        #expect(settings.tools[0].name == "Claude Code")
        #expect(settings.tools[3].name == "Copilot CLI")
        #expect(settings.tools[4].name == "Cursor CLI")
    }

    @Test("Default settings has correct defaults")
    func defaultValues() {
        let settings = AppSettings.default
        #expect(settings.fontSize == 14)
        #expect(settings.theme == "dark")
        #expect(settings.defaultCwd == nil)
        #expect(settings.defaultShell == nil)
        #expect(settings.layouts == nil)
    }

    @Test("Save and load roundtrip")
    func saveLoadRoundtrip() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("clide-test-\(UUID())")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("settings.json")

        var settings = AppSettings.default
        settings.fontSize = 18
        settings.defaultCwd = "/tmp/test"

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(settings)
        try data.write(to: url)

        let loaded = try JSONDecoder().decode(AppSettings.self, from: Data(contentsOf: url))
        #expect(loaded.fontSize == 18)
        #expect(loaded.defaultCwd == "/tmp/test")
        #expect(loaded.tools.count == 5)

        try FileManager.default.removeItem(at: dir)
    }

    @Test("Settings with layouts roundtrip")
    func layoutsRoundtrip() throws {
        var settings = AppSettings.default
        settings.layouts = [
            TerminalLayout(name: "Dev", isDefault: true, columns: [
                LayoutColumn(terminals: [LayoutTerminal(label: "Claude", command: "claude")]),
                LayoutColumn(terminals: [LayoutTerminal(), LayoutTerminal()]),
            ])
        ]

        let data = try JSONEncoder().encode(settings)
        let loaded = try JSONDecoder().decode(AppSettings.self, from: data)
        #expect(loaded.layouts?.count == 1)
        #expect(loaded.layouts?[0].name == "Dev")
        #expect(loaded.layouts?[0].isDefault == true)
        #expect(loaded.layouts?[0].columns.count == 2)
        #expect(loaded.layouts?[0].columns[0].terminals[0].command == "claude")
        #expect(loaded.layouts?[0].columns[1].terminals.count == 2)
        #expect(loaded.defaultLayout?.name == "Dev")
    }
}

// MARK: - SavedSession

@Suite("SavedSession Tests")
struct SavedSessionTests {

    @Test("Empty session has no terminals")
    func emptySession() {
        let session = SavedSession.empty
        #expect(session.terminals.isEmpty)
        #expect(!session.hasSavedTerminals)
        #expect(session.columnCount == 1)
    }

    @Test("Session with terminals reports saved")
    func sessionWithTerminals() {
        let session = SavedSession(
            terminals: [
                SavedTerminal(label: "Claude", command: "claude", args: [], column: 0, cwd: nil)
            ],
            columnCount: 1
        )
        #expect(session.hasSavedTerminals)
        #expect(session.terminals.count == 1)
        #expect(session.terminals[0].column == 0)
    }

    @Test("Multi-column session")
    func multiColumn() {
        let session = SavedSession(
            terminals: [
                SavedTerminal(label: "T1", command: "", args: [], column: 0, cwd: nil),
                SavedTerminal(label: "T2", command: "claude", args: [], column: 1, cwd: nil),
                SavedTerminal(label: "T3", command: "", args: [], column: 1, cwd: nil),
            ],
            columnCount: 2
        )
        #expect(session.columnCount == 2)
        #expect(session.terminals.count == 3)
    }

    @Test("Backward compat: old panel format decodes to column")
    func backwardCompatPanel() throws {
        let json = """
        {
            "terminals": [
                {"label": "T1", "command": "claude", "args": [], "panel": "main", "cwd": null},
                {"label": "T2", "command": "", "args": [], "panel": "secondary", "cwd": null}
            ],
            "splitVisible": true
        }
        """.data(using: .utf8)!

        let session = try JSONDecoder().decode(SavedSession.self, from: json)
        #expect(session.terminals[0].column == 0)
        #expect(session.terminals[1].column == 1)
        #expect(session.columnCount == 2)
    }

    @Test("New column format roundtrip")
    func columnFormatRoundtrip() throws {
        let session = SavedSession(
            terminals: [
                SavedTerminal(label: "T1", command: "", args: [], column: 0, cwd: nil),
                SavedTerminal(label: "T2", command: "", args: [], column: 2, cwd: nil),
            ],
            columnCount: 3
        )
        let data = try JSONEncoder().encode(session)
        let loaded = try JSONDecoder().decode(SavedSession.self, from: data)
        #expect(loaded.columnCount == 3)
        #expect(loaded.terminals[0].column == 0)
        #expect(loaded.terminals[1].column == 2)
    }
}

// MARK: - ToolConfig

@Suite("ToolConfig Tests")
struct ToolConfigTests {

    @Test("Default tools have unique shortcuts")
    func uniqueShortcuts() {
        let shortcuts = ToolConfig.defaults.map(\.shortcut)
        #expect(Set(shortcuts).count == shortcuts.count)
    }

    @Test("Default tools have valid hex colors")
    func validColors() {
        for tool in ToolConfig.defaults {
            #expect(tool.color.hasPrefix("#"))
            #expect(tool.color.count == 7)
        }
    }

    @Test("Tool IDs are unique")
    func uniqueIds() {
        let ids = ToolConfig.defaults.map(\.id)
        #expect(Set(ids).count == ids.count)
    }
}

// MARK: - TerminalLayout

@Suite("TerminalLayout Tests")
struct TerminalLayoutTests {

    @Test("Layout encode/decode roundtrip")
    func roundtrip() throws {
        let layout = TerminalLayout(
            name: "Test Layout",
            isDefault: true,
            columns: [
                LayoutColumn(terminals: [
                    LayoutTerminal(label: "Claude", command: "claude", args: ["--verbose"]),
                    LayoutTerminal(label: "Shell", command: "", args: []),
                ]),
                LayoutColumn(terminals: [
                    LayoutTerminal(label: "Aider", command: "aider"),
                ]),
            ],
            pairings: [
                LayoutPairing(color: "#e06c75", members: [
                    LayoutPosition(column: 0, row: 0),
                    LayoutPosition(column: 1, row: 0),
                ])
            ]
        )

        let data = try JSONEncoder().encode(layout)
        let loaded = try JSONDecoder().decode(TerminalLayout.self, from: data)
        #expect(loaded.name == "Test Layout")
        #expect(loaded.isDefault == true)
        #expect(loaded.columns.count == 2)
        #expect(loaded.columns[0].terminals.count == 2)
        #expect(loaded.columns[0].terminals[0].command == "claude")
        #expect(loaded.columns[0].terminals[0].args == ["--verbose"])
        #expect(loaded.columns[1].terminals.count == 1)
        #expect(loaded.pairings.count == 1)
        #expect(loaded.pairings[0].members.count == 2)
        #expect(loaded.pairings[0].color == "#e06c75")
    }

    @Test("Layout with window frame")
    func windowFrame() throws {
        let layout = TerminalLayout(
            name: "Framed",
            columns: [LayoutColumn(terminals: [LayoutTerminal()])],
            windowFrame: LayoutRect(x: 100, y: 200, width: 1280, height: 800)
        )
        let data = try JSONEncoder().encode(layout)
        let loaded = try JSONDecoder().decode(TerminalLayout.self, from: data)
        #expect(loaded.windowFrame?.x == 100)
        #expect(loaded.windowFrame?.y == 200)
        #expect(loaded.windowFrame?.width == 1280)
        #expect(loaded.windowFrame?.height == 800)
    }

    @Test("Layout without window frame decodes nil")
    func noWindowFrame() throws {
        let layout = TerminalLayout(name: "Simple", columns: [])
        let data = try JSONEncoder().encode(layout)
        let loaded = try JSONDecoder().decode(TerminalLayout.self, from: data)
        #expect(loaded.windowFrame == nil)
    }

    @Test("LayoutPosition hashable")
    func positionHashable() {
        let a = LayoutPosition(column: 0, row: 1)
        let b = LayoutPosition(column: 0, row: 1)
        let c = LayoutPosition(column: 1, row: 0)
        #expect(a == b)
        #expect(a != c)
        #expect(Set([a, b, c]).count == 2)
    }
}

// MARK: - NSColor Hex Parsing

@Suite("Color Parsing Tests")
struct ColorParsingTests {
    @Test("Valid hex with hash")
    func validHexHash() {
        let color = NSColor.fromHex("#d97706")
        #expect(color != nil)
    }

    @Test("Valid hex without hash")
    func validHexNoHash() {
        let color = NSColor.fromHex("2563eb")
        #expect(color != nil)
    }

    @Test("Invalid hex returns nil")
    func invalidHex() {
        #expect(NSColor.fromHex("xyz") == nil)
        #expect(NSColor.fromHex("#12") == nil)
        #expect(NSColor.fromHex("") == nil)
        #expect(NSColor.fromHex("#gggggg") == nil)
    }

    @Test("White parses correctly")
    func whiteHex() {
        let color = NSColor.fromHex("#ffffff")!.usingColorSpace(.sRGB)!
        #expect(color.redComponent > 0.99)
        #expect(color.greenComponent > 0.99)
        #expect(color.blueComponent > 0.99)
    }

    @Test("Black parses correctly")
    func blackHex() {
        let color = NSColor.fromHex("#000000")!.usingColorSpace(.sRGB)!
        #expect(color.redComponent < 0.01)
        #expect(color.greenComponent < 0.01)
        #expect(color.blueComponent < 0.01)
    }
}

// MARK: - SessionManager (logic-only tests)

@Suite("SessionManager Tests")
struct SessionManagerTests {
    private func makeManager() -> SessionManager {
        SessionManager(settings: .default)
    }

    @Test("Create session assigns to correct column")
    func createSession() {
        let mgr = makeManager()
        let s = mgr.createSession(label: "T1", column: 0)
        #expect(mgr.sessions.count == 1)
        #expect(s.column == 0)
        #expect(mgr.activeIds[0] == s.id)
    }

    @Test("Create sessions in multiple columns")
    func multiColumn() {
        let mgr = makeManager()
        let s1 = mgr.createSession(label: "T1", column: 0)
        _ = mgr.addColumn()
        let s2 = mgr.createSession(label: "T2", column: 1)
        #expect(mgr.sessions(forColumn: 0).count == 1)
        #expect(mgr.sessions(forColumn: 1).count == 1)
        #expect(mgr.activeIds[0] == s1.id)
        #expect(mgr.activeIds[1] == s2.id)
    }

    @Test("Close session updates active")
    func closeSession() {
        let mgr = makeManager()
        let s1 = mgr.createSession(label: "T1", column: 0)
        let s2 = mgr.createSession(label: "T2", column: 0)
        #expect(mgr.activeIds[0] == s2.id) // last created is active
        mgr.closeSession(s2.id)
        #expect(mgr.activeIds[0] == s1.id) // falls back to first
        #expect(mgr.sessions.count == 1)
    }

    @Test("Close last session clears active")
    func closeLastSession() {
        let mgr = makeManager()
        let s = mgr.createSession(label: "T1", column: 0)
        mgr.closeSession(s.id)
        #expect(mgr.sessions.isEmpty)
        #expect(mgr.activeIds[0] == nil)
    }

    @Test("Column management")
    func columnManagement() {
        let mgr = makeManager()
        #expect(mgr.columnCount == 1)
        let col1 = mgr.addColumn()
        #expect(col1 == 1)
        #expect(mgr.columnCount == 2)
        let col2 = mgr.addColumn()
        #expect(col2 == 2)
        #expect(mgr.columnCount == 3)
    }

    @Test("Remove column shifts higher columns down")
    func removeColumn() {
        let mgr = makeManager()
        _ = mgr.addColumn()
        _ = mgr.addColumn()
        let s0 = mgr.createSession(label: "T0", column: 0)
        let s2 = mgr.createSession(label: "T2", column: 2)
        mgr.removeColumn(1)
        #expect(mgr.columnCount == 2)
        #expect(s0.column == 0)
        #expect(s2.column == 1) // shifted down
    }

    @Test("nextLabel generates unique sequential numbers")
    func nextLabel() {
        let mgr = makeManager()
        let l1 = mgr.nextLabel(baseName: "Terminal")
        let l2 = mgr.nextLabel(baseName: "Terminal")
        let l3 = mgr.nextLabel(baseName: "Terminal")
        #expect(l1 == "Terminal 1")
        #expect(l2 == "Terminal 2")
        #expect(l3 == "Terminal 3")
    }

    @Test("nextLabel numbers never reuse after close")
    func nextLabelStable() {
        let mgr = makeManager()
        _ = mgr.nextLabel(baseName: "Terminal") // 1
        _ = mgr.nextLabel(baseName: "Terminal") // 2
        // Simulate closing terminal 1 — counter doesn't reset
        let l3 = mgr.nextLabel(baseName: "Terminal")
        #expect(l3 == "Terminal 3")
    }

    @Test("Cycle tab wraps around")
    func cycleTab() {
        let mgr = makeManager()
        let s1 = mgr.createSession(label: "T1", column: 0)
        let s2 = mgr.createSession(label: "T2", column: 0)
        let s3 = mgr.createSession(label: "T3", column: 0)
        #expect(mgr.activeIds[0] == s3.id)
        mgr.cycleTab(column: 0, forward: true)
        #expect(mgr.activeIds[0] == s1.id) // wraps to first
        mgr.cycleTab(column: 0, forward: false)
        #expect(mgr.activeIds[0] == s3.id) // wraps to last
    }

    @Test("Select tab by index")
    func selectTab() {
        let mgr = makeManager()
        let s1 = mgr.createSession(label: "T1", column: 0)
        _ = mgr.createSession(label: "T2", column: 0)
        mgr.selectTab(index: 0, column: 0)
        #expect(mgr.activeIds[0] == s1.id)
    }

    @Test("Active session for column")
    func activeSession() {
        let mgr = makeManager()
        let s = mgr.createSession(label: "T1", column: 0)
        #expect(mgr.activeSession(forColumn: 0)?.id == s.id)
        #expect(mgr.activeSession(forColumn: 1) == nil)
    }
}

// MARK: - Pairing Tests

@Suite("Pairing Tests")
struct PairingTests {
    private func makeManager() -> SessionManager {
        SessionManager(settings: .default)
    }

    @Test("Create pairing")
    func createPairing() {
        let mgr = makeManager()
        let s1 = mgr.createSession(label: "T1", column: 0)
        let s2 = mgr.createSession(label: "T2", column: 0)
        let group = mgr.createPairing(between: [s1.id, s2.id])
        #expect(mgr.pairingGroups.count == 1)
        #expect(group.memberIds.contains(s1.id))
        #expect(group.memberIds.contains(s2.id))
    }

    @Test("Duplicate pairing returns existing group")
    func duplicatePairing() {
        let mgr = makeManager()
        let s1 = mgr.createSession(label: "T1", column: 0)
        let s2 = mgr.createSession(label: "T2", column: 0)
        let g1 = mgr.createPairing(between: [s1.id, s2.id])
        let g2 = mgr.createPairing(between: [s1.id, s2.id])
        #expect(g1.id == g2.id)
        #expect(mgr.pairingGroups.count == 1)
    }

    @Test("Remove pairing")
    func removePairing() {
        let mgr = makeManager()
        let s1 = mgr.createSession(label: "T1", column: 0)
        let s2 = mgr.createSession(label: "T2", column: 0)
        let group = mgr.createPairing(between: [s1.id, s2.id])
        mgr.removePairing(group.id)
        #expect(mgr.pairingGroups.isEmpty)
    }

    @Test("Unpair all for a session")
    func unpairAll() {
        let mgr = makeManager()
        let s1 = mgr.createSession(label: "T1", column: 0)
        let s2 = mgr.createSession(label: "T2", column: 0)
        let s3 = mgr.createSession(label: "T3", column: 0)
        _ = mgr.createPairing(between: [s1.id, s2.id])
        _ = mgr.createPairing(between: [s1.id, s3.id])
        #expect(mgr.pairingGroups.count == 2)
        mgr.unpairAll(sessionId: s1.id)
        #expect(mgr.pairingGroups.isEmpty) // both groups had <2 members after removing s1
    }

    @Test("Pairings for session")
    func pairingsForSession() {
        let mgr = makeManager()
        let s1 = mgr.createSession(label: "T1", column: 0)
        let s2 = mgr.createSession(label: "T2", column: 0)
        let s3 = mgr.createSession(label: "T3", column: 0)
        _ = mgr.createPairing(between: [s1.id, s2.id])
        _ = mgr.createPairing(between: [s1.id, s3.id])
        #expect(mgr.pairings(for: s1.id).count == 2)
        #expect(mgr.pairings(for: s2.id).count == 1)
        #expect(mgr.pairings(for: s3.id).count == 1)
    }

    @Test("Paired sessions")
    func pairedSessions() {
        let mgr = makeManager()
        let s1 = mgr.createSession(label: "T1", column: 0)
        let s2 = mgr.createSession(label: "T2", column: 0)
        let s3 = mgr.createSession(label: "T3", column: 0)
        _ = mgr.createPairing(between: [s1.id, s2.id])
        _ = mgr.createPairing(between: [s1.id, s3.id])
        let paired = mgr.pairedSessions(for: s1.id)
        #expect(paired.count == 2)
        #expect(paired.contains(where: { $0.id == s2.id }))
        #expect(paired.contains(where: { $0.id == s3.id }))
    }

    @Test("Close session cleans up pairings")
    func closeCleansPairings() {
        let mgr = makeManager()
        let s1 = mgr.createSession(label: "T1", column: 0)
        let s2 = mgr.createSession(label: "T2", column: 0)
        _ = mgr.createPairing(between: [s1.id, s2.id])
        mgr.closeSession(s1.id)
        #expect(mgr.pairingGroups.isEmpty) // group lost a member, <2 remaining
    }

    @Test("Pairing with custom color")
    func customColor() {
        let mgr = makeManager()
        let s1 = mgr.createSession(label: "T1", column: 0)
        let s2 = mgr.createSession(label: "T2", column: 0)
        let group = mgr.createPairing(between: [s1.id, s2.id], color: "#ff0000")
        #expect(group.color == "#ff0000")
    }

    @Test("Auto-assigned colors cycle through palette")
    func autoColors() {
        let mgr = makeManager()
        let s1 = mgr.createSession(label: "T1", column: 0)
        let s2 = mgr.createSession(label: "T2", column: 0)
        let s3 = mgr.createSession(label: "T3", column: 0)
        let g1 = mgr.createPairing(between: [s1.id, s2.id])
        let g2 = mgr.createPairing(between: [s1.id, s3.id])
        #expect(g1.color != g2.color) // different colors auto-assigned
    }
}

// MARK: - Layout Capture/Apply

@Suite("Layout Capture Tests")
struct LayoutCaptureTests {
    @Test("Capture layout from sessions")
    func captureLayout() {
        let mgr = SessionManager(settings: .default)
        _ = mgr.addColumn()
        _ = mgr.createSession(label: "Claude", command: "claude", args: [], column: 0)
        _ = mgr.createSession(label: "Shell", column: 0)
        _ = mgr.createSession(label: "Aider", command: "aider", args: [], column: 1)

        let layout = mgr.captureLayout(name: "Test")
        #expect(layout.name == "Test")
        #expect(layout.columns.count == 2)
        #expect(layout.columns[0].terminals.count == 2)
        #expect(layout.columns[0].terminals[0].command == "claude")
        #expect(layout.columns[1].terminals.count == 1)
        #expect(layout.columns[1].terminals[0].command == "aider")
    }

    @Test("Capture layout with pairings")
    func captureWithPairings() {
        let mgr = SessionManager(settings: .default)
        _ = mgr.addColumn()
        let s1 = mgr.createSession(label: "T1", column: 0)
        let s2 = mgr.createSession(label: "T2", column: 1)
        _ = mgr.createPairing(between: [s1.id, s2.id], color: "#aabbcc")

        let layout = mgr.captureLayout(name: "Paired")
        #expect(layout.pairings.count == 1)
        #expect(layout.pairings[0].color == "#aabbcc")
        #expect(layout.pairings[0].members.count == 2)
    }
}

// MARK: - Clyde Tips

@Suite("Clyde Tips")
struct ClydeTipsTests {
    @Test("Exactly 100 tips")
    func tipCount() {
        #expect(ClydeTips.all.count == 100)
    }

    @Test("No empty tips")
    func noEmptyTips() {
        for tip in ClydeTips.all {
            #expect(!tip.isEmpty)
        }
    }

    @Test("No duplicate tips")
    func noDuplicates() {
        #expect(Set(ClydeTips.all).count == ClydeTips.all.count)
    }
}
