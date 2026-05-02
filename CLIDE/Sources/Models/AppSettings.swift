import Foundation

struct AppSettings: Codable {
    var tools: [ToolConfig]
    var theme: String
    var fontSize: Int
    var fontFamily: String
    var fontColor: String?
    var defaultShell: String?
    var defaultCwd: String?
    var promptForDirectory: Bool?
    var layouts: [TerminalLayout]?

    var defaultLayout: TerminalLayout? {
        layouts?.first(where: \.isDefault)
    }

    static let `default` = AppSettings(
        tools: ToolConfig.defaults,
        theme: "dark",
        fontSize: 14,
        fontFamily: "Menlo",
        fontColor: nil,
        defaultShell: nil,
        defaultCwd: nil,
        promptForDirectory: nil,
        layouts: nil
    )

    static var configURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("com.clide.app", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("settings.json")
    }

    static func load() -> AppSettings {
        guard let data = try? Data(contentsOf: configURL),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return .default
        }
        return settings
    }

    func save() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: Self.configURL)
    }
}
