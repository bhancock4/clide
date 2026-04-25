import Testing
import Foundation
@testable import CLIDE

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
}

@Suite("SavedSession Tests")
struct SavedSessionTests {

    @Test("Empty session has no terminals")
    func emptySession() {
        let session = SavedSession.empty
        #expect(session.terminals.isEmpty)
        #expect(!session.hasSavedTerminals)
    }

    @Test("Session with terminals reports saved")
    func sessionWithTerminals() {
        let session = SavedSession(
            terminals: [
                SavedTerminal(label: "Claude", command: "claude", args: [], panel: "main", cwd: nil)
            ],
            sidebarVisible: false,
            splitVisible: false
        )
        #expect(session.hasSavedTerminals)
        #expect(session.terminals.count == 1)
    }
}

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
}
