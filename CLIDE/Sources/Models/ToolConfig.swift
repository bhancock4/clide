import Foundation

struct ToolConfig: Codable, Identifiable, Equatable {
    var id: String { command + shortcut }
    var name: String
    var command: String
    var args: [String]
    var shortcut: String
    var color: String

    static let defaults: [ToolConfig] = [
        ToolConfig(name: "Claude Code", command: "claude", args: [], shortcut: "C", color: "#d97706"),
        ToolConfig(name: "Gemini CLI", command: "gemini", args: [], shortcut: "G", color: "#2563eb"),
        ToolConfig(name: "Aider", command: "aider", args: [], shortcut: "A", color: "#16a34a"),
        ToolConfig(name: "Copilot CLI", command: "gh", args: ["copilot"], shortcut: "O", color: "#6e40c9"),
        ToolConfig(name: "Cursor CLI", command: "cursor", args: [], shortcut: "U", color: "#00b4d8"),
    ]
}
