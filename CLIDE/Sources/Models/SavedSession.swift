import Foundation

struct SavedTerminal: Codable {
    var label: String
    var command: String
    var args: [String]
    var panel: String  // "main" or "secondary"
    var cwd: String?
}

struct SavedSession: Codable {
    var terminals: [SavedTerminal]
    var sidebarVisible: Bool
    var splitVisible: Bool

    static let empty = SavedSession(terminals: [], sidebarVisible: false, splitVisible: false)

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
        try data.write(to: Self.fileURL)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    var hasSavedTerminals: Bool {
        !terminals.isEmpty
    }
}
