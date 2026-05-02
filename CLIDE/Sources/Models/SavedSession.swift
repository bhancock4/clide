import Foundation

struct SavedTerminal: Codable {
    var label: String
    var command: String
    var args: [String]
    var column: Int
    var cwd: String?

    private enum CodingKeys: String, CodingKey {
        case label, command, args, column, panel, cwd
    }

    init(label: String, command: String, args: [String], column: Int, cwd: String?) {
        self.label = label
        self.command = command
        self.args = args
        self.column = column
        self.cwd = cwd
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        label = try c.decode(String.self, forKey: .label)
        command = try c.decode(String.self, forKey: .command)
        args = try c.decode([String].self, forKey: .args)
        cwd = try c.decodeIfPresent(String.self, forKey: .cwd)
        // Backward compat: old format used "panel" string
        if let col = try? c.decode(Int.self, forKey: .column) {
            column = col
        } else if let panel = try? c.decode(String.self, forKey: .panel) {
            column = panel == "secondary" ? 1 : 0
        } else {
            column = 0
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(label, forKey: .label)
        try c.encode(command, forKey: .command)
        try c.encode(args, forKey: .args)
        try c.encode(column, forKey: .column)
        try c.encodeIfPresent(cwd, forKey: .cwd)
    }
}

struct SavedSession: Codable {
    var terminals: [SavedTerminal]
    var columnCount: Int

    static let empty = SavedSession(terminals: [], columnCount: 1)

    private enum CodingKeys: String, CodingKey {
        case terminals, columnCount, splitVisible
    }

    init(terminals: [SavedTerminal], columnCount: Int) {
        self.terminals = terminals
        self.columnCount = columnCount
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        terminals = try c.decode([SavedTerminal].self, forKey: .terminals)
        if let cc = try? c.decode(Int.self, forKey: .columnCount) {
            columnCount = cc
        } else if let split = try? c.decode(Bool.self, forKey: .splitVisible) {
            columnCount = split ? 2 : 1
        } else {
            columnCount = 1
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(terminals, forKey: .terminals)
        try c.encode(columnCount, forKey: .columnCount)
    }

    static var fileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("com.clide.app", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("session.json")
    }

    static func load() -> SavedSession {
        guard let data = try? Data(contentsOf: fileURL),
              let session = try? JSONDecoder().decode(SavedSession.self, from: data) else {
            return .empty
        }
        return session
    }

    func save() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(self)
        let tmpURL = Self.fileURL.deletingLastPathComponent().appendingPathComponent("session.tmp.json")
        try data.write(to: tmpURL)
        _ = try FileManager.default.replaceItemAt(Self.fileURL, withItemAt: tmpURL)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    var hasSavedTerminals: Bool {
        !terminals.isEmpty
    }
}
