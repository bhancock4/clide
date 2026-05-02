import Foundation

struct TerminalLayout: Codable, Identifiable {
    var id: UUID
    var name: String
    var isDefault: Bool
    var columns: [LayoutColumn]
    var pairings: [LayoutPairing]
    var windowFrame: LayoutRect?

    init(id: UUID = UUID(), name: String, isDefault: Bool = false,
         columns: [LayoutColumn] = [], pairings: [LayoutPairing] = [],
         windowFrame: LayoutRect? = nil) {
        self.id = id
        self.name = name
        self.isDefault = isDefault
        self.columns = columns
        self.pairings = pairings
        self.windowFrame = windowFrame
    }
}

struct LayoutRect: Codable {
    var x: Double, y: Double, width: Double, height: Double
}

struct LayoutColumn: Codable {
    var terminals: [LayoutTerminal]

    init(terminals: [LayoutTerminal] = []) {
        self.terminals = terminals
    }
}

struct LayoutTerminal: Codable {
    var label: String
    var command: String
    var args: [String]

    init(label: String = "Terminal", command: String = "", args: [String] = []) {
        self.label = label
        self.command = command
        self.args = args
    }
}

struct LayoutPairing: Codable, Identifiable {
    var id: UUID
    var color: String
    var members: [LayoutPosition]

    init(id: UUID = UUID(), color: String, members: [LayoutPosition]) {
        self.id = id
        self.color = color
        self.members = members
    }
}

struct LayoutPosition: Codable, Hashable {
    var column: Int
    var row: Int
}
